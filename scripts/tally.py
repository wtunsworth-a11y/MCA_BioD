#!/usr/bin/env python3
"""Tally camera trap identifications submitted as GitHub issues.

Run by .github/workflows/site.yml. Reads every issue labelled
"identification" or submitted from the website (marked in its body), keeps each person's latest identification per image,
and writes:

  docs/data/ids.json    every counted identification (read by the website)
  docs/data/labels.csv  one row per image with its consensus label

The consensus rule (minimum identifications, agreement percentage and
target rank) is read from docs/data/config.json and matches the website.

Environment: GITHUB_TOKEN and REPO ("owner/name"). Set DRY_RUN=1 to skip
labelling and commenting on issues.
"""
import csv
import json
import os
import re
import sys
import urllib.request
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "docs", "data")
RANKS = ["species", "genus", "family"]  # finest first
TOKEN = os.environ.get("GITHUB_TOKEN", "")
REPO = os.environ.get("REPO", "")
DRY = os.environ.get("DRY_RUN") == "1"
API = "https://api.github.com"


def api(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "camtrap-tally")
    if TOKEN:
        req.add_header("Authorization", "Bearer " + TOKEN)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read() or "null")


MARK = "<!-- camtrap-identification v1 -->"


def is_identification(issue):
    """Submitted from the website (marker in the body) or the GitHub issue form (label)."""
    labels = {l["name"] for l in issue.get("labels", [])}
    return "identification" in labels or MARK in (issue.get("body") or "")


def fetch_issues():
    # Visitors can't set labels, so website submissions are found by the marker in their body.
    out, page = [], 1
    while True:
        batch = api("GET", f"/repos/{REPO}/issues?state=all&per_page=100&page={page}")
        out += [i for i in batch if "pull_request" not in i and is_identification(i)]
        if len(batch) < 100:
            return out
        page += 1


def parse_body(body):
    """Issue forms render as '### Label' followed by the answer."""
    fields, current = {}, None
    for line in (body or "").splitlines():
        m = re.match(r"^###\s+(.*)$", line)
        if m:
            current = m.group(1).strip().lower()
            fields[current] = []
        elif current is not None:
            fields[current].append(line)
    clean = {}
    for k, v in fields.items():
        text = re.split(r"\n-{3,}\s*\n", "\n".join(v) + "\n")[0].strip()   # drop the website's footer
        clean[k] = "" if text == "_No response_" else text
    return clean


def cap(s):
    return s[:1].upper() + s[1:].lower() if s else ""


PROVISIONAL = re.compile(r"\b(sp|spp|cf|aff|nov)\b\.?|\bn\.\s*sp\b|[\"'\u201c\u201d\u2018\u2019?]|\s\S+\s", re.I)


def normalise(f, g, s):
    """Return (family, genus, species epithet, provisional text).

    Working names such as sp. "Managalas", cf. or aff. are kept as
    provisional text and count at genus level only."""
    raw = (s or "").strip()
    provisional = raw if raw and PROVISIONAL.search(raw) else ""
    if provisional:
        s = ""
    family = cap((f or "").strip().split(" ")[0]) if (f or "").strip() else ""
    genus = cap((g or "").strip().split(" ")[0]) if (g or "").strip() else ""
    sp = re.sub(r"\s+", " ", (s or "").strip().lower())
    if genus and sp.startswith(genus.lower() + " "):
        sp = sp[len(genus) + 1:]
    if not genus and " " in sp:
        a, b = sp.split(" ", 1)
        genus, sp = cap(a), b
    if re.fullmatch(r"(sp|spp|sp\.|spp\.|\?|unknown)", sp):
        sp = ""
    sp = sp.split(" ")[0] if sp else ""
    if not genus:
        sp = ""
    return family, genus, sp, provisional


def label_issue(number, name, comment=None):
    if DRY:
        return
    try:
        api("POST", f"/repos/{REPO}/issues/{number}/labels", {"labels": [name]})
        if comment:
            api("POST", f"/repos/{REPO}/issues/{number}/comments", {"body": comment})
    except Exception as e:  # labelling is a courtesy; never fail the tally over it
        print(f"could not label #{number}: {e}", file=sys.stderr)


def consensus(ids, gfm, cfg):
    total = len(ids)
    tally = {r: Counter() for r in RANKS}
    unid = 0
    for v in ids:
        if v["unid"]:
            unid += 1
            continue
        fam = v["family"] or gfm.get(v["genus"], "")
        if fam:
            tally["family"][fam] += 1
        if v["genus"]:
            tally["genus"][v["genus"]] += 1
            if v["species"]:
                tally["species"][v["genus"] + " " + v["species"]] += 1
    result = None
    if total >= cfg["minIds"]:
        if unid / total * 100 >= cfg["agreePct"]:
            result = ("unid", "Not identifiable", unid)
        else:
            for r in RANKS:
                top = sorted(tally[r].items(), key=lambda x: (-x[1], x[0]))
                if top and top[0][1] / total * 100 >= cfg["agreePct"] and (len(top) == 1 or top[1][1] < top[0][1]):
                    result = (r, top[0][0], top[0][1])
                    break
    if total < cfg["minIds"]:
        status = "needs"
    elif not result:
        status = "disputed"
    elif result[0] == "unid" or RANKS.index(result[0]) <= RANKS.index(cfg["targetRank"]):
        status = "resolved"
    else:
        status = "partial"
    return status, result, total


def main():
    if not REPO:
        sys.exit("Set REPO=owner/name")
    images = json.load(open(os.path.join(DATA, "images.json")))
    cfg = json.load(open(os.path.join(DATA, "config.json")))
    # Several photos of one animal form a set; identifications count for the set's first photo.
    lead = {i["id"]: (i.get("set") or [i["id"]])[0] for i in images}
    known = {i["id"].lower(): lead[i["id"]] for i in images}
    # IUCN common names (e.g. "New Guinea Quoll") -> (family, genus, epithet)
    common = {}
    try:
        for sp_ in json.load(open(os.path.join(DATA, "iucn.json")))["species"]:
            if sp_.get("common"):
                common[sp_["common"].strip().lower()] = (sp_["family"], sp_["genus"], sp_["species"])
    except FileNotFoundError:
        pass
    for i in images:                      # old IDs of images that were moved
        for a in i.get("aliases", []):
            known[a.lower()] = lead[i["id"]]

    latest, notes = {}, []
    for iss in sorted(fetch_issues(), key=lambda i: i["created_at"]):
        labels = {l["name"] for l in iss.get("labels", [])}
        if "identification" not in labels:
            label_issue(iss["number"], "identification")
        if iss["state"] == "closed" and iss.get("state_reason") == "not_planned":
            continue
        if labels & {"withdrawn", "invalid", "spam"}:
            continue
        f = parse_body(iss["body"])
        raw_id = (f.get("image id") or "").strip().replace(" ", "_")
        img = known.get(raw_id.lower())
        if not img:
            if "check-image-id" not in labels:
                label_issue(iss["number"], "check-image-id",
                            f"Thanks! I couldn't match the image ID `{raw_id or '(blank)'}` to an image on the website, "
                            "so this identification isn't counted yet. Please edit the issue and put the image ID "
                            "(for example `Macropodidae_001`) in the Image ID box.\n\n_This is an automatic message._")
            continue
        unid = "[x]" in (f.get("not identifiable") or "").lower()
        fam, gen, sp, prov = normalise(f.get("family"), f.get("genus"), f.get("species epithet"))
        hit = common.get((f.get("species epithet") or "").strip().lower())
        if hit and (not gen or gen == hit[1]):
            fam, gen, sp, prov = fam or hit[0], hit[1], hit[2], ""
        flag_text = (f.get("flags") or "").lower()
        flags = dict(range="[x] possible range extension" in flag_text,
                     newsp="[x] possibly an undescribed species" in flag_text,
                     review="[x] needs a specialist" in flag_text)
        note = (f.get("notes and ideas") or f.get("reasoning (optional)") or "")
        note = re.split(r"\n-{3,}\s*\n", note)[0].strip()[:1500]   # drop the website's footer
        vote = unid or bool(fam or gen)
        if not vote and not note and not any(flags.values()):
            if "check-image-id" not in labels:
                label_issue(iss["number"], "check-image-id",
                            "Thanks! This submission has no name, flag or note, so there is nothing to show yet. "
                            "Please edit the issue to add a family or genus, tick *Not identifiable*, or write a note.\n\n"
                            "_This is an automatic message._")
            continue
        user = iss["user"]["login"]
        entry = dict(
            image=img, user=user, vote=vote, family="" if unid else fam, genus="" if unid else gen,
            species="" if unid else sp, provisional="" if unid else prov, unid=unid, flags=flags,
            confidence=(f.get("confidence") or "").strip(),
            local=(f.get("local or common name (optional)") or "").strip()[:80],
            note=note, at=iss["created_at"], url=iss["html_url"])
        if vote:
            latest[(img, user)] = entry          # one counted vote per person per image
        else:
            notes.append(entry)                  # notes are all kept
        if "counted" not in labels:
            label_issue(iss["number"], "counted")

    ids = sorted(list(latest.values()) + notes, key=lambda v: (v["image"], v["at"]))
    with open(os.path.join(DATA, "ids.json"), "w") as fh:
        json.dump(ids, fh, indent=1)

    # genus -> most common family, so genus-only IDs still count at family level
    gf = defaultdict(Counter)
    votes = [v for v in ids if v["vote"]]
    for v in votes:
        if v["genus"] and v["family"]:
            gf[v["genus"]][v["family"]] += 1
    gfm = {g: c.most_common(1)[0][0] for g, c in gf.items()}

    by_img, flagged = defaultdict(list), defaultdict(Counter)
    for v in votes:
        by_img[v["image"]].append(v)
    for v in ids:
        for k, on in v["flags"].items():
            if on:
                flagged[v["image"]][k] += 1
    with open(os.path.join(DATA, "labels.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["image_id", "observation_id", "file", "curated_family", "curated_genus", "grid", "station", "camera",
                    "elevation_m", "date", "time", "clock_unreliable", "status", "consensus_rank",
                    "consensus_family", "consensus_genus", "consensus_species", "agreement_pct",
                    "agreeing_ids", "total_ids", "flag_range_extension", "flag_undescribed", "flag_review", "rule_min_ids", "rule_agree_pct", "rule_target_rank"])
        for im in images:
            status, res, total = consensus(by_img[lead[im["id"]]], gfm, cfg)
            fam = gen = sp = ""
            if res and res[0] == "species":
                gen, sp = res[1].split(" ", 1)
                fam = gfm.get(gen, "")
            elif res and res[0] == "genus":
                gen = res[1]
                fam = gfm.get(gen, "")
            elif res and res[0] == "family":
                fam = res[1]
            w.writerow([im["id"], lead[im["id"]], im["file"], im["family"], im["curatedGenus"], im["grid"], im["station"],
                        im["camera"], im["elevation"], im["date"], im["time"], "yes" if im["clockReset"] else "",
                        status, res[0] if res else "", fam, gen, sp,
                        round(res[2] / total * 100) if res else "", res[2] if res else "", total,
                        flagged[lead[im["id"]]]["range"] or "", flagged[lead[im["id"]]]["newsp"] or "", flagged[lead[im["id"]]]["review"] or "",
                        cfg["minIds"], cfg["agreePct"], cfg["targetRank"]])
    print(f"{len(votes)} votes and {len(notes)} notes; {len(ids)} entries across {len(by_img)} observations")


if __name__ == "__main__":
    main()

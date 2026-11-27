#!/usr/bin/env python3
"""Build docs/data/iucn.json: species in the survey's families that the
IUCN Red List records in Papua New Guinea, with accepted name, authority,
common name, Red List category, elevation limits and habitats.

Needs an IUCN Red List API v4 token in IUCN_REDLIST_KEY (or a proxy that
adds it). Usage: python3 scripts/iucn_candidates.py
"""
import json, os, sys, time, urllib.request
API = "https://api.iucnredlist.org/api/v4"
KEY = os.environ.get("IUCN_REDLIST_KEY", "dummy")
FAMILIES = ["Macropodidae", "Peramelidae", "Phalangeridae", "Varanidae", "Dasyuridae",
            # candidates for the "small mammal, family unknown" images
            "Muridae", "Petauridae", "Pseudocheiridae", "Burramyidae", "Acrobatidae", "Soricidae"]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "data", "iucn.json")

def get(path, tries=4):
    for t in range(tries):
        try:
            req = urllib.request.Request(API + path, headers={"Authorization": KEY, "User-Agent": "camtrap-iucn"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:
            if t == tries - 1: raise
            time.sleep(2 * (t + 1))

def pages(path):
    out, p = [], 1
    while True:
        d = get(f"{path}{'&' if '?' in path else '?'}page={p}&per_page=100")
        a = d.get("assessments", [])
        out += a
        if len(a) < 100: return out
        p += 1

pg_ids = {a["sis_taxon_id"] for a in pages("/countries/PG?latest=true&scope_code=1")}
print("PNG assessments:", len(pg_ids), file=sys.stderr)
species = []
for fam in FAMILIES:
    fam_as = [a for a in pages(f"/taxa/family/{fam}?latest=true&scope_code=1") if a["sis_taxon_id"] in pg_ids]
    print(fam, len(fam_as), file=sys.stderr)
    for a in fam_as:
        d = get(f"/assessment/{a['assessment_id']}")
        tx, si = d["taxon"], d.get("supplementary_info") or {}
        if not tx.get("species"): continue
        common = next((c["name"] for c in tx.get("common_names", []) if c.get("main")), None) or \
                 next((c["name"] for c in tx.get("common_names", []) if c.get("language") == "eng"), "")
        species.append(dict(
            family=fam, genus=tx["genus_name"], species=tx["species_name"], name=tx["scientific_name"],
            authority=tx.get("authority") or "", common=common,
            category=(d.get("red_list_category") or {}).get("code", ""),
            elevMin=si.get("lower_elevation_limit"), elevMax=si.get("upper_elevation_limit"),
            countries=sorted(l["code"] for l in d.get("locations", []) if l.get("code") and len(l["code"]) == 2),
            habitats=sorted({(h.get("description") or {}).get("en", "") for h in d.get("habitats", [])} - {""}),
            year=d.get("year_published"), url=d.get("url")))
        time.sleep(0.15)
species.sort(key=lambda s: (s["family"], s["name"]))
json.dump({"source": "IUCN Red List of Threatened Species, API v4", "retrieved": time.strftime("%Y-%m-%d"),
           "species": species}, open(OUT, "w"), indent=1)
print("wrote", len(species), "species to", OUT, file=sys.stderr)

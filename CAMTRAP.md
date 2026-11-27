# Managalas Camera Trap ID website

Website: https://wtunsworth-a11y.github.io/MCA_BioD/

A community identification site for curated camera trap images from the
Managalas Plateau, Ijivitari District, Oro (Northern) Province, Papua New
Guinea. It is a pilot of the Managalas project, funded by the European
Union, and is built to be handed on to a Papua New Guinean group.

## How it works

| Part | Where |
|---|---|
| Website (static) | `docs/index.html`, published by GitHub Pages |
| Images and manifest | `docs/images/<Family>/`, `docs/images/manifest.csv` |
| Thumbnails | `docs/thumbs/` |
| Image metadata | `docs/data/images.json` |
| Consensus rule | `docs/data/config.json` (`minIds`, `agreePct`, `targetRank`, `repo`) |
| Maps | `docs/data/geo.json` (PNG outline, relief and grid squares; no station coordinates) |
| IUCN candidate species | `docs/data/iucn.json`, built by `scripts/iucn_candidates.py` |
| Identification form | `.github/ISSUE_TEMPLATE/identification.yml` |
| Tally and deploy | `.github/workflows/site.yml` runs `scripts/tally.py` |
| Results | `docs/data/ids.json` and `docs/data/labels.csv`, written by the workflow |

1. A specialist opens an image on the website and fills in the
   identification form beside it, then presses **Submit on GitHub**. GitHub
   opens with the identification written out (marked in the issue body),
   and they press **Create**. A GitHub issue form also exists as a fallback.
2. They give a name at whatever rank they are confident of. Working names
   (`sp. "Managalas"`, `cf.`, `aff.`) count at genus level. They can
   also flag a possible range extension, a possibly undescribed species,
   or a need for specialist review, or leave a note with no name.
3. The workflow runs on every issue change. It keeps each person's latest
   identification per image, labels the issue `identification` and `counted`, rebuilds
   `ids.json` and `labels.csv`, and redeploys the site. This takes a few
   minutes.
4. A name is accepted when an image has at least `minIds`
   identifications and `agreePct`% agree, at the finest rank that passes.

To withdraw an identification, close its issue as "not planned". To
remove a spam or mistaken entry, add the `invalid` label.

## Setting it up (one time)

1. Merge this branch into the repository's default branch.
2. Settings > Pages > Build and deployment > Source: **GitHub Actions**.
3. Actions tab > "Camera trap ID website" > **Run workflow** (or push any
   change under `docs/`).

## Adding images

Add the image to `docs/images/<Family>/` with the next free number, add
its row to `docs/images/manifest.csv`, and regenerate `images.json` and
the thumbnail. Or upload the files anywhere in the repository and ask for
them to be filed.

## Handing over

Transfer the repository (Settings > General > Transfer ownership) to the
new group's GitHub account, then update `repo` in `docs/data/config.json`.
The identifications travel with the repository because they are its issues.

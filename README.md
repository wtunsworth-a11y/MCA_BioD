# Target 4 species ranking for Papua New Guinea

An R reimplementation of the protocol in:

> Akçakaya, H.R., Mannion, N.L.M., et al. (2026). Identifying and ranking species
> that need urgent management action to achieve Target 4 of the Global
> Biodiversity Framework. *Global Ecology and Conservation* 72: e04536.
> https://doi.org/10.1016/j.gecco.2026.e04536

The protocol uses global IUCN Red List data to build a national ranked list of
threatened species likely to need urgent, species-specific management action
under Target 4 of the Kunming–Montreal Global Biodiversity Framework. The code
runs for Papua New Guinea (`PG`) by default and works for any IUCN country code.

## How it works

Each CR, EN or VU species that occurs in the country gets four weights:

| Weight | Range | Based on | Code |
|---|---|---|---|
| **Risk** (Table 1) | CR 4, EN 2, VU 1 | Red List category | `risk_weight()` |
| **Decline** (Table 2) | 0–10 | Criteria A, C1, C2, E, B…b(i–v), continuing-decline fields, population trend | `decline_weight()` |
| **Restriction** (Table 3) | 0–10 | Criteria B, C, D, population size, AOO, EOO, number of locations, "area restricted" | `restriction_weight()` |
| **Endemism** (Table 4) | 10 / number of countries | Countries where the species is extant and native | `endemism_weight()` |

- **Priority 1:** `PS1 = Risk × Endemism × Decline × Restriction` is greater than 0 (Eq. 1). The maximum score is 4000.
- **Priority 2:** for species with PS1 = 0, `PS2 = Risk × Endemism × max(Decline, Restriction)` is greater than 0 (Eq. 2).
- **EW species** are listed unranked at the top (Section 2.3.3).

The final list is EW species, then Priority 1 ranked by PS1, then Priority 2
ranked by PS2. Tied species share a rank.

## Running it

You need R (4.1 or later) with `httr2`, `jsonlite` and `testthat`, and an
IUCN Red List API v4 token from <https://api.iucnredlist.org>.

```bash
echo 'IUCN_REDLIST_KEY=your_token_here' >> .Renviron   # git-ignored
Rscript run_target4.R            # Papua New Guinea
Rscript run_target4.R FJ         # any other ISO-2 country code
Rscript tests/testthat.R         # unit tests
```

Options:
- `--refresh` downloads again instead of using the cache.
- `--missing-trend-unknown` treats a blank population trend as "Unknown" (see the decisions below).

The first run downloads every latest global assessment listed for the country,
about 10,000 for PNG. It then downloads the full record for each CR, EN, VU or
EW species, which takes 10–20 minutes. Responses are cached in `data/cache/`,
so later runs are instant.

Outputs, in `output/`:

- `PG_target4_ranked.csv` is the national ranked list. It shows the four weights, PS1 and PS2, and the input values behind each weight, so every score can be checked.
- `PG_target4_all_scored.csv` lists every threatened or EW species that qualifies in the country, including those not listed, with all weights and continuing-decline flags.

The cache and outputs are git-ignored because IUCN's Terms of Use restrict
redistributing Red List data, and this repository is public.

## Code layout

```
R/utils.R        parsing helpers (numeric ranges, yes/no fields)
R/criteria.R     Red List criteria string parser ("A2cd+3cd; B1ab(iii)" -> tokens)
R/weights.R      Tables 1–4
R/scoring.R      Eq. 1, Eq. 2, EW handling, ranking
R/iucn_api.R     IUCN Red List API v4 client with on-disk cache
R/standardise.R  API JSON -> one row per species
run_target4.R    end-to-end script
tests/           testthat tests, one per table row plus a synthetic end-to-end case
```

## Decisions not fully specified in the paper

The original pipeline is at github.com/JonahMorreale/RedList_Target4Species.
This version was written from the paper alone. These are the choices I made
where the paper leaves room:

1. **Which presence and origin count.**
   - A species qualifies in the focal country if it is *Extant* or *Possibly Extinct* there, with origin *Native*, *Reintroduced* or *Assisted Colonisation*.
   - For EW species, *Extinct Post-1500* also qualifies.
   - The endemism denominator counts countries with the same presence and origin.
   - Only two-letter country codes are counted. The API also returns sub-national units such as `NWG-IJ` (Papua) or `QLD-QU` (Queensland), which would otherwise inflate the count.
   - *Possibly Extant* and *Origin Uncertain* are excluded. Edit `default_presence` / `default_origin` in `R/standardise.R` to change this.
2. **Numeric ranges.** Population size, AOO, EOO and number of locations are free text in the Red List, e.g. `"1000-2500"`. The upper bound is used, so a species counts as restricted only if the whole range is below the threshold. Set `num_summary = "min"` or `"mean"` in `standardise_assessments()` to change this.
3. **Blank population trend.**
   - Table 2 gives 0.5 for `populationTrend = Unknown`.
   - A trend that is missing entirely gets 0 by default.
   - `--missing-trend-unknown` gives it 0.5 instead.
4. **Criteria version 2.3.**
   - Older assessments use 2.3 criteria. The paper converts these with a table in its Supplementary material, which I don't have.
   - Here, 2.3 criteria strings are parsed with the 3.1 rules. Their syntax matches, but some meanings differ (for example, 2.3 A1/A2 and the B subcriteria).
   - `criteria_version` is kept in the output so these species can be checked.
5. **Species only.** Subpopulation and infraspecific assessments are dropped, which matches the paper's species focus. Set `species_only = FALSE` to keep them.
6. **Ties** share the same (minimum) rank and are displayed alphabetically.

## Check against the paper (Papua New Guinea)

Run on 27 Nov 2026 against the live API:

| | This implementation | Paper, Table 6 |
|---|---|---|
| Threatened + EW species | 1,299 qualifying in-country (1,328 listed) | 1,322 |
| Priority 1 | 914 (70.4%) | 916 (69.3%) |
| Priority 2 | 385 | — |
| Top score | 4000 (*Paphiopedilum bougainvilleanum*, CR) | max 4000 |

Of the 29 listed assessments that don't qualify in PNG:
- 10 are *Possibly Extant* there.
- 10 are *Presence Uncertain*.
- 9 are introduced, vagrant or of uncertain origin.

Each alternative choice changes Priority 1 by at most 5 species:

| Alternative | Priority 1 |
|---|---|
| Include *Possibly Extant* | 918 |
| Treat a missing trend as *Unknown* | 919 |
| Use the lower bound of numeric ranges | 917 |

Eight qualifying species use 2.3 criteria, and eight have no recorded
population trend. The remaining gap with the paper most likely comes from
Red List updates between versions 2025-2 and 2026-1.

## Site prioritisation: Managalas Conservation Area

`run_mca.R` narrows the national list to the Managalas Conservation Area (MCA)
in Oro Province, using GBIF occurrence records. The MCA is WDPA site 555651673:
a Conservation Area designated in 2017 under local community governance,
2,133 km².

**Inputs**
- The cached national IUCN data from `run_target4.R`.
- The MCA boundary from WDPA, saved to `data/mca/managalas_wdpa.geojson`.
  It isn't committed because of WDPA's licence. To download it again:

```bash
mkdir -p data/mca
curl -s "https://data-gis.unep-wcmc.org/server/rest/services/ProtectedSites/The_World_Database_of_Protected_Areas/MapServer/1/query?where=site_id%3D555651673&outFields=*&returnGeometry=true&outSR=4326&f=geojson" -o data/mca/managalas_wdpa.geojson
```

**Run**

```bash
Rscript run_mca.R                  # 25 km buffer
Rscript run_mca.R --buffer-km 10
```

**Method**
1. Each species name is matched to the GBIF backbone taxonomy.
   - Where GBIF treats an IUCN species as a synonym of a broader species, it is counted by its own name key. GBIF restricts that key to records filed under the name. Otherwise six IUCN *Actinodaphne* species, all lumped into *A. nitida* by GBIF, would each get the others' 193 records.
   - Any key still shared by two IUCN species is flagged in `gbif_shared_key`.
2. GBIF records are counted inside the boundary, within the buffer (25 km by default) and across PNG.
   - Fossils and living collections are excluded, as are records with geospatial issues.
   - GBIF caps request size, so the query polygons are simplified at 200–300 m.
3. Each species gets an evidence tier:
   - **1, recorded in the site:** a GBIF record inside the boundary.
   - **2, recorded nearby:** a record within the buffer but none inside.
   - **3, no records nearby:** a land or freshwater species with no record in the buffer.
   - **4, marine only:** IUCN lists only the Marine system.
4. Within each tier, Priority 1 species come before Priority 2, then species are ranked by the national score.
5. `site_share` is the buffer's share of the species' GBIF records in PNG. It roughly shows how much the area matters for that species. Survey effort biases it heavily.

**Result** (25 km buffer, 28 Nov 2026):

| Tier | Species | Priority 1 | Priority 2 |
|---|---|---|---|
| 1, recorded in the site | 10 | 9 | 1 |
| 2, recorded nearby | 16 | 14 | 2 |
| 3, no records nearby | 926 | 859 | 67 |
| 4, marine only | 347 | 32 | 315 |

Tier 1 includes *Ornithoptera alexandrae* (Queen Alexandra's birdwing,
the MCA's flagship species) and *Goura scheepmakeri*.

**Caveats**
- GBIF holds only about 3,400 records inside the MCA. Tier 3 therefore mostly means "not surveyed", not "absent".
- IUCN range maps or Area of Habitat (from the IUCN spatial data download, which needs a login) would show which tier 3 species could occur there. So would an elevation and habitat match against the plateau. Local and Indigenous knowledge, and survey reports for the plateau, should add species GBIF misses.

## Caveats from the paper

The ranked list is a **starting point** for national review, not a final
Target 4 list. Data Deficient species, national Red List assessments, cultural
priorities, and the feasibility and cost of recovery are all outside the
automated protocol. See Sections 4.1–4.2 of the paper.

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

## Caveats from the paper

The ranked list is a **starting point** for national review, not a final
Target 4 list. Data Deficient species, national Red List assessments, cultural
priorities, and the feasibility and cost of recovery are all outside the
automated protocol. See Sections 4.1–4.2 of the paper.

---

**Also in this repository:** the Melanesian Camera Trap ID website, a
community identification site for camera trap images. See
[CAMTRAP.md](CAMTRAP.md).

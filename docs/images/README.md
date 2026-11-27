# Curated camera trap images for community identification

Images from the Managalas camera trap survey that need identification
below family level. They are published on the Managalas Camera Trap ID website
(https://wtunsworth-a11y.github.io/MCA_BioD/), which is built from the
`docs/` folder.

## Layout

    images/<Family>/<Family>_<NNN>.jpg

Each folder is a family, so a specialist in one group can find their
images in one place:

| Folder | Images | Curated as |
|---|---|---|
| Macropodidae | 21 | family |
| Peramelidae | 35 | family |
| Phalangeridae | 11 | genus *Phalanger* |
| Varanidae | 11 | genus *Varanus* |
| Dasyuridae | 3 | genus *Dasyurus* (2) or family only (1) |
| Small_mammals_family_unknown | 15 | "small mammal"; family not yet known |

Images are numbered within their family, in order of capture date, with
clock-reset frames last. Numbers are never reused, so uploads with the
same file name (such as `Peramelidae 1.jpeg` and `Peramelidae_1.jpg`)
always get separate IDs. Exact byte-for-byte copies were dropped, and
their names are kept in `original_filename`.

## manifest.csv

One row per image:

- `image_id`: the image's identifier everywhere, including on the ID board.
- `original_filename`: the name it was uploaded with.
- `family` and `curated_genus`: the curator's grouping. Empty `genus` and `species` columns are for the agreed IDs.
- `curator_hint`: a name taken from the uploaded file name (e.g. `Isoodon`). The board does not show it to identifiers, so it can't bias their IDs.
- `same_activation_as` and `observation_id`: photos from one camera activation (same camera, same minute on the data strip) form a set, identified once. Frames minutes apart are not grouped.
- `survey_location`: a neutral code for the fixed 1 km square the camera is in. The key linking codes to squares is kept privately by the project, not in this repository.
- Context read from the camera's data strip: grid, station, camera (CT1 or CT2 at the station), date, time, time of day,
  temperature, and whether the frame is colour (day) or infrared (night).
  This is supporting information for identifiers. It does not affect how the files are organised.

`Macropodidae_021` was first filed as `Dasyuridae_003` (it was in the *Dasyurus*
upload, named `Dorcopsis.jpeg`) and moved to Macropodidae. The old ID
still works on the website and in the identification form.

## Clock resets

Some cameras lost power and their clocks reset, so the date and time on
their data strip are wrong. The `clock_unreliable` column marks these
frames, and the ID board warns identifiers about them. Eight frames are
obviously affected because they are stamped January 2020 (see
`clock_unreliable`). A reset can also produce a plausible-looking 2026 date,
so mark any other cameras you know were affected.

## Location

All images are from Oro (Northern) Province, Ijivitari District. Grids
G09, G35, G43, G46, G51, G57 and most of G55 are in Afore Rural LLG, and
G38 and station G55_G1 are in Oro Bay Rural LLG. The `province`,
`district` and `llg` columns come from testing each station against
geoBoundaries ADM1-3 boundaries.

## Location data

Elevation for each station comes from SRTM 1-arc-second data, using the
survey's station coordinates (WGS 84 / UTM zone 55S). Exact coordinates
are deliberately kept out of this public repository, because some of
these species are of conservation concern.

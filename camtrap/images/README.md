# Curated camera trap images for community identification

Images from the Managalas camera trap survey that need identification
below family level. They will be posted to the community ID board
(`../camera-trap-id.html`).

## Layout

    images/<Family>/<Family>_<NNN>.jpg

Folders follow what is already known about each image: its family.
Each image gets the next free number in its family, ordered by capture
date. Numbers are never reused, so a new upload called
`Macropodidae 1.jpg` becomes the next free number in that family and
never overwrites an existing file.

## manifest.csv

One row per image:

- `image_id`: the image's identifier everywhere, including on the ID board.
- `original_filename`: the name it was uploaded with.
- `family`, plus empty `genus` and `species` columns to fill once the community agrees.
- Context read from the camera's data strip: grid, station, burst frame, date, time,
  temperature, and whether the frame is colour (day) or infrared (night).
  This is supporting information for identifiers. It does not affect how the files are organised.

## Clock resets

Some cameras lost power and their clocks reset, so the date and time on
their data strip are wrong. The `clock_unreliable` column marks these
frames, and the ID board warns identifiers about them. Only one frame is
obviously affected so far: `Peramelidae_001` is stamped 18 Jan 2020 on a
2026 deployment. A reset can also produce a plausible-looking 2026 date,
so mark any other cameras you know were affected.

## Location data

Elevation for each station comes from SRTM 1-arc-second data, using the
survey's station coordinates (WGS 84 / UTM zone 55S). Exact coordinates
are deliberately kept out of this public repository, because some of
these species are of conservation concern.

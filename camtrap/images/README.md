# Curated camera trap images for community identification

Images from the Managalas camera trap survey (Browning cameras) that
need identification below family level. They will be posted to the
community ID board (`../camera-trap-id.html`).

## Layout

    images/<Family>/<Grid>/<Family>_<Grid>-<Station>_<YYYY-MM-DD>_<HHMM>_f<frame>.jpg

Every part of the name is read from the data strip at the bottom of the
frame. For example, `G46 C2 2` is grid G46, station C2, burst frame 2.
The time uses the 24-hour clock. This scheme gives every image a unique
name, even when the original filenames clash between upload batches.

`manifest.csv` has one row per image: the new path, the original
upload filename, family, empty `genus` and `species` columns for the
agreed IDs, grid, station, date, time, temperature, and whether the
frame is colour (day) or infrared (night).

## Adding more images

Upload new images anywhere in the repository and ask for them to be
refiled. Each one is renamed from its data strip, filed by family and
grid, and added to the manifest. Duplicate filenames from different
batches are fine, because the new name comes from the frame itself.

## Data checks

- `Peramelidae/G55/Peramelidae_G55-F7_2020-01-18_1159_f1.jpg`: the frame
  is stamped 18 Jan 2020, but this deployment ran in 2026, so the
  camera's clock was probably reset. Check the deployment log for the
  real date before using this frame's timestamp.

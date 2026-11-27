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

## Data checks

- `Peramelidae_001`: the frame is stamped 18 Jan 2020, but this deployment ran in
  2026, so the camera's clock was probably reset. Check the deployment
  log for the real date.

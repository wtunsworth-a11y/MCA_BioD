# Choosing images to submit

These guidelines are for camera trap projects adding images to the website.
It starts with the Managalas Plateau and is open to camera trap projects
across Papua New Guinea, and in time to the wider region (Indonesia,
Solomon Islands and others). The aim is a small, carefully chosen set
that the community can work through, not every frame from a survey.

## Send selected images

- Choose images that genuinely need a second opinion: animals you can't
  name with confidence after checking them yourself.
- Send tens of images per group, not hundreds.
- Send no more than 2 or 3 images of the same thing (the same species,
  station and situation). Pick the clearest ones.

## Group photos of one animal

- If one animal appears in several photos, send up to 3 as a set, chosen
  to show different features: head and ears, tail, feet, flank or markings.
- Keep a set together by putting it in its own folder, or by giving the
  files the same name with a, b, c (for example `G46_C2_0716a.jpg`,
  `G46_C2_0716b.jpg`).
- On the website a set appears as one sighting, and identifications count
  once for the whole set. In `manifest.csv` the photos of a set share an
  `observation_id`; in `docs/data/images.json` they share a `set` list.

## Keep the originals

- Send the original JPEG at full size, with the camera's data strip (date,
  time, station) intact. Don't crop, brighten or edit it.
- Note the group (family) if you know it, and any doubts about the date if
  the camera's clock may have reset after a battery failure.
- Tell us the project, country and province, and each station's
  coordinates. The site only shows a general location (the survey grid or
  a similar area), never exact camera positions.
- Leave out photos that show people, houses or gardens.

## Previously identified images

- Confirmed identifications are welcome as references: a few clear
  examples per species help people compare.
- Send them in a separate folder named `reference`, with the confirmed name
  and who identified it, either in the file name or in a short list.
- References are shown as examples, not put to the vote.

## How to send them

Upload a zip per group to the repository (or send it to the project team)
and ask for it to be filed. Each image is renamed from its data strip,
filed by family, linked to its set, and added to the manifest.

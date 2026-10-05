# Quieto artwork generation

All artwork is text-free and lives in `Resources/Artwork`.

- `ambience-*.png`: eight individually generated gouache illustrations for the bundled sound loops.
- `need-*.png`: eight individually generated illustrations for the daily check-in situations.
- `session-*.png`: 48 deterministic, unique compositions generated from the approved Quieto gouache source family by `Scripts/generate_session_artwork.swift`.

## Shared prompt direction

> Square 1:1 editorial gouache illustration for Quieto, an iOS meditation app. Match the existing Quieto style: naive hand-painted gouache, visible brush texture, simple bold shapes, premium restrained composition. Palette led by deep navy #101D30, muted midnight blue, cream and subtle mint #A8E5D5, with at most one muted natural accent. No text, letters, logo, gradient, neon, photorealism, 3D, faces or medical imagery. Centered subject safe for square cards and rounded thumbnail crops.

Each ambience prompt then named its actual scene (campfire, forest, river, ocean, rain, white noise, pink noise or summer night). Each check-in prompt described the concrete situation through a calm object or abstract metaphor, never through a distressed human face.

To regenerate the deterministic session variants from the checked-in source family:

```sh
swift Scripts/generate_session_artwork.swift
```

To regenerate the original 30-second MP3 ambience loops (requires `brew install lame`):

```sh
swift Scripts/generate_ambiences.swift
```

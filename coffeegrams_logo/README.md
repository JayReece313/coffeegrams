# CoffeeGrams Logo

The CoffeeGrams brand mark: a **tilted balance scale weighed down by a pan full
of coffee beans** — a nod to the product name (coffee + *grams* / precision
weighing). Drawn in the app's three brand colors:

| Role | Color | Hex |
|---|---|---|
| Field / background | Cream | `#F5EBDD` |
| Beans, post, strings, fulcrum | Espresso brown | `#372718` |
| Beam, pans, base, bean crease | Caramel gold | `#CD8B32` |

## Files

- **`render.swift`** — the source. A macOS CoreGraphics script (a *design tool*,
  not part of the shipping app) that draws the mark and writes two 1024×1024
  PNGs:
  - **`CoffeeGramsIcon.png`** — full art on the warm cream field → the **app
    icon** (`Assets.xcassets/AppIcon.appiconset/AppIcon.png`).
  - **`CoffeeGramsLogoMark.png`** — the mark on a **transparent** field → the
    in-app **home-header lockup** beside the "CoffeeGrams" wordmark
    (`Assets.xcassets/Logo.imageset/`).

## Regenerate

```sh
cd coffeegrams_logo
swift render.swift
# then copy the PNGs into the asset catalog:
#   CoffeeGramsIcon.png     -> CoffeeGrams/CoffeeGrams/Assets.xcassets/AppIcon.appiconset/AppIcon.png
#   CoffeeGramsLogoMark.png -> CoffeeGrams/CoffeeGrams/Assets.xcassets/Logo.imageset/LogoMark.png
```

To tweak the design, edit the geometry constants in `render.swift` (tilt angle,
bean count/positions, beam length, pan radius) and re-run.

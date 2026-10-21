Hardlock app icon

Variants: light (default), dark, tinted.
Each folder has a .iconset (standard macOS sizes, 16-1024px) and a 1024px SVG master.
Below 32px the keyhole is omitted for clarity.

scripts/build-app.sh builds AppIcon.icns from the light iconset. It renames
"-2x" to "@2x" on the way, because iconutil requires that naming.

The dark and tinted variants are kept as sources only. macOS asset catalogs drop
appearance variants for app icons, so using them would mean building an
Icon Composer (.icon) file.

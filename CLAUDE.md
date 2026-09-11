# calc-for-garmin

## UI guidelines

Every UI addition or change must work well for two very different users:
- **Daily users** — power users who use the calculator constantly and want speed (minimal taps, predictable button placement, no friction).
- **First-time / non-users** — people opening it for the first time who need it to be obvious and intuitive with zero explanation.

When adding or changing UI, design for both: keep it fast and predictable for repeat use, but keep labels, layout, and flow clear enough that a new user isn't confused. Don't trade one off for the other.

## Keep web layout templates in sync

`web/index.html` defines `PRESETS` (layout templates like classic, pocket, beginner, oneHand, advanced, mirror) and the token registries `TOKEN_LABEL`/`TOKEN_COLOR`/`REQUIRED_POOL` that back them.

Whenever a new button/token is added anywhere on the watch keypad (basic, sci, adv, var, or units screen), it must also be added to `web/index.html`:
- add the token to `TOKEN_LABEL` (and `TOKEN_COLOR` if it needs a specific basic-keypad color)
- add it to the relevant `*_DEFAULT` array so it's part of `REQUIRED_POOL`
- update every existing preset in `PRESETS` that touches that screen's layout, so all templates stay valid full permutations and none of them go stale or break seed import/export.

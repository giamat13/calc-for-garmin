# calc-for-garmin

## UI guidelines

Every UI addition or change must work well for two very different users:
- **Daily users** — power users who use the calculator constantly and want speed (minimal taps, predictable button placement, no friction).
- **First-time / non-users** — people opening it for the first time who need it to be obvious and intuitive with zero explanation.

When adding or changing UI, design for both: keep it fast and predictable for repeat use, but keep labels, layout, and flow clear enough that a new user isn't confused. Don't trade one off for the other.

## Keep web layout templates in sync

`web/index.html` defines `PRESETS` (layout templates like classic, pocket, beginner, oneHand, advanced, mirror) and the token registries `TOKEN_LABEL`/`TOKEN_COLOR`/`REQUIRED_POOL` that back them.

Whenever a new button/token is added anywhere on a customizable watch keypad screen (currently basic, sci, adv, or units - see the pool comment at the top of `SeedConfig.mc` for the current list), it must also be added to `web/index.html`:
- add the token to `TOKEN_LABEL` (and `TOKEN_COLOR` if it needs a specific basic-keypad color)
- add it to the relevant `*_DEFAULT` array so it's part of `REQUIRED_POOL`
- update every existing preset in `PRESETS` that touches that screen's layout, so all templates stay valid full permutations and none of them go stale or break seed import/export.

A screen that's a fixed grid instead (like VAR or NAV) isn't part of this pool at all and doesn't need any of the above - only a customizable screen's tokens go through `web/index.html`.

## Old SEED codes must keep working

From now on, a SEED code someone already generated and pasted into their watch settings must keep working after future updates - it should not silently fall back to defaults just because the app changed. Before changing anything that affects the SEED format (`SeedConfig.mc`'s pool layout/size, `VALID_MENU_ITEMS`, the `"1|...` version prefix, or the equivalent `web/index.html` registries), check whether the change would invalidate existing pasted seeds, and if so, prefer a backward-compatible approach (e.g. only appending new tokens/screens rather than resizing or reordering existing ones, or bumping the format version and still parsing the old one) over one that breaks them. Flag it to the user before doing anything that would break existing seeds.

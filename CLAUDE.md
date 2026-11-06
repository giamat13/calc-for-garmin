# calc-for-garmin

## Branches

There is one branch, `main`, and one store listing (`a6abb4e5-0f89-430e-990c-4b75cd2ad0da`, UUID in `manifest.xml`). The old `old-devices` branch and its listing (`3f93c3d9`) are retired; don't merge them back and don't delete them without asking.

One build covers every device in `manifest.xml` (`minApiLevel` 1.4.0), in two flavours chosen per device in `monkey.jungle`:
- **Full build** - the default. Everything is compiled in.
- **Lean build** - the 44 devices with the 64KB widget cap (the `<device>.excludeAnnotations` lines in `monkey.jungle`, e.g. fenix3, fenix5, vivoactive3, fr245, instinct2). Code marked `(:exclude_oldwidget)` is stripped and its `(:oldwidget_only)` stand-in is compiled instead. No GRAPH/BASE/COLOR/COUNTER/FORMULAS/HISTORY/QR setup.

How it works: `base.excludeAnnotations = oldwidget_only` strips the lean stand-ins from every device; each lean device line sets `<device>.excludeAnnotations = exclude_oldwidget`, which strips the full-only code. Every annotated declaration exists in source once in full and once as a stand-in, so both builds always compile from the same files. When you add a feature that is heavy (graphs, extra screens, big formula tables), mark it `(:exclude_oldwidget)` and add a `(:oldwidget_only)` stand-in for any shared code that still calls it. Check the lean build for fenix3 and the full build for vivoactive4s after such a change.

API 2.4+ calls (Storage/Properties) go through `readProp`/`readStore`/`writeStore` in `SeedConfig.mc`, which fall back to `AppBase.getProperty`/`setProperty` on older API levels.

Signing: `.vscode/settings.json` (tracked) points at the developer key; the key files themselves are gitignored. Command-line builds use `developer_key_new.der` in the repo root.

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

From now on, a SEED code someone already generated and pasted into their watch settings must keep working after future updates - it should not silently fall back to defaults just because the app changed. Before changing anything that affects the SEED format (`SeedConfig.mc`'s pool layout/size, `VALID_MENU_ITEMS`, the `"1|...` version prefix, or the equivalent `web/index.html` registries), check whether the change would invalidate existing pasted seeds.

It's fine to reshape the format itself (resize/reorder the pool, bump the version prefix, restructure a registry) as long as both sides keep parsing old seeds correctly:
- `web/index.html`'s "Load SEED" import still recognizes and correctly loads seeds in every previous format/version.
- The watch's `SeedConfig.mc` parser still recognizes and correctly applies seeds in every previous format/version.

In practice this usually means keeping the old parser path alongside the new one, branching on the version prefix (or the pool size/shape) rather than deleting old handling. What's not okay is a change that makes an old seed parse into something silently wrong or fall back to defaults - if you can't keep both sides truly reading it correctly, flag it to the user before doing anything that would break existing seeds.

## Old watches

Memory-limit (64KB widget) build errors are fixed with the lean-build annotations described under Branches, not with a separate branch. If a device hits the limit, add it to the lean device list in `monkey.jungle` and mark the heavy code it still pulls in. Keep the lean build's stand-ins working so old watches never show a blank or crashing screen.

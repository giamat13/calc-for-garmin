import Toybox.Lang;
import Toybox.Application;

// Parses the compact "1|C=...|M=...|P=..." seed string produced by the
// setup web page (https://giamat13.github.io/calc-for-garmin/) and pasted
// into this app's Connect IQ settings ("calcSeed" property). Anything
// missing, malformed, or from an unknown format version falls back to the
// stock defaults - a bad/partial seed just looks like the plain
// calculator instead of crashing.
//
// "P=" is ONE combined pool of every button on every customizable screen
// (basic + scientific + advanced + variables + unit-categories, BACK
// buttons included) - 83 tokens total, in fixed screen order. Any token
// can sit in any slot on any screen (every action is self-contained and
// doesn't care which screen it's tapped from), so buttons can be moved
// between screens, not just reordered within one. The whole pool must be
// an exact permutation of the stock 83 - nothing added, removed, or
// duplicated - or it's rejected wholesale and every screen falls back to
// its own default slice.
class SeedConfig {

    // 6 colors, in order: digit, operator, equals, clear/destructive,
    // nav (MENU/BACK), top display background.
    var colors as Array<Number>;
    // Which tools appear in the MENU screen, and in what order. "Setup"
    // and "BACK" are always appended by the view itself.
    var menuItems as Array<String>;
    // Per-screen slices of the pool - see class comment.
    var basicLayout as Array<String>;   // 20 tokens, 4 cols x 5 rows
    var sciLayout as Array<String>;     // 24 tokens, 4 cols x 6 rows
    var advLayout as Array<String>;     // 17 tokens, 4 cols x 5 rows (last row uneven)
    var varLayout as Array<String>;     // 10 tokens, 2 cols x 5 rows
    var unitsLayout as Array<String>;   // 12 tokens, 3 cols x 4 rows

    private static var instance as SeedConfig?;

    static const DEFAULT_COLORS = [0x23233A, 0xFFB020, 0x00D68F, 0xFF5470, 0x7C4DFF, 0x14141F] as Array<Number>;
    static const DEFAULT_MENU = ["sci", "units", "tip", "rnd", "var"] as Array<String>;
    static const VALID_MENU_ITEMS = ["sci", "units", "tip", "rnd", "var"] as Array<String>;

    static const BASIC_LEN = 20;
    static const SCI_LEN = 24;
    static const ADV_LEN = 17;
    static const VAR_LEN = 10;
    static const UNITS_LEN = 12;

    static const DEFAULT_BASIC_LAYOUT = [
        "c", "del", "pct", "div",
        "1", "2", "3", "mul",
        "4", "5", "6", "sub",
        "7", "8", "9", "add",
        "menu", "0", "dot", "eq"
    ] as Array<String>;

    // "eqIns" = sci's EQ (inserts "=" to build an equation, distinct from
    // basic's "eq" which evaluates); "backMenu"/"backSci" are BACK buttons
    // - named by destination, not by screen, since the identical action
    // works the same wherever it's placed.
    static const DEFAULT_SCI_LAYOUT = [
        "sin", "cos", "tan", "sqrt", "log", "ln", "sqr", "x",
        "open", "close", "pow", "pi", "e", "c", "del", "adv",
        "uc", "rnd", "tip", "eqIns", "ans", "curl", "curr", "backMenu"
    ] as Array<String>;

    static const DEFAULT_ADV_LAYOUT = [
        "asin", "acos", "atan", "fact", "inv", "cbrt", "absv", "mod",
        "ee", "cube", "floor", "ceil", "c", "del", "pow10", "var", "backSci"
    ] as Array<String>;

    static const DEFAULT_VAR_LAYOUT = [
        "stoA", "rclA", "stoB", "rclB", "stoC", "rclC", "stoD", "rclD", "clr", "backMenu"
    ] as Array<String>;

    static const DEFAULT_UNITS_LAYOUT = [
        "dist", "wt", "temp", "spd", "pace", "vol", "area", "time", "pres", "enrg", "cur", "backMenu"
    ] as Array<String>;

    static function get() as SeedConfig {
        if (instance == null) {
            instance = new SeedConfig(Application.Properties.getValue("calcSeed") as String?);
        }
        return instance as SeedConfig;
    }

    // Re-parses from Properties - call after the phone's Settings UI may
    // have changed them (App.onSettingsChanged).
    static function reload() as Void {
        instance = new SeedConfig(Application.Properties.getValue("calcSeed") as String?);
    }

    function initialize(seed as String?) {
        colors = DEFAULT_COLORS;
        menuItems = DEFAULT_MENU;
        basicLayout = DEFAULT_BASIC_LAYOUT;
        sciLayout = DEFAULT_SCI_LAYOUT;
        advLayout = DEFAULT_ADV_LAYOUT;
        varLayout = DEFAULT_VAR_LAYOUT;
        unitsLayout = DEFAULT_UNITS_LAYOUT;
        if (seed == null || seed.length() < 2 || !seed.substring(0, 2).equals("1|")) {
            return;
        }
        var fields = splitStr(seed.substring(2, seed.length()), "|");
        for (var i = 0; i < fields.size(); i++) {
            var f = fields[i];
            if (f.length() > 2 && f.substring(0, 2).equals("C=")) {
                var parsedColors = parseColors(f.substring(2, f.length()));
                if (parsedColors != null) {
                    colors = parsedColors as Array<Number>;
                }
            } else if (f.length() > 2 && f.substring(0, 2).equals("M=")) {
                var parsedMenu = parseMenu(f.substring(2, f.length()));
                if (parsedMenu != null && (parsedMenu as Array<String>).size() > 0) {
                    menuItems = parsedMenu as Array<String>;
                }
            } else if (f.length() > 2 && f.substring(0, 2).equals("P=")) {
                var pool = parsePermutation(f.substring(2, f.length()), requiredPool());
                if (pool != null) {
                    var p = pool as Array<String>;
                    var offset = 0;
                    basicLayout = sliceArr(p, offset, BASIC_LEN); offset += BASIC_LEN;
                    sciLayout = sliceArr(p, offset, SCI_LEN); offset += SCI_LEN;
                    advLayout = sliceArr(p, offset, ADV_LEN); offset += ADV_LEN;
                    varLayout = sliceArr(p, offset, VAR_LEN); offset += VAR_LEN;
                    unitsLayout = sliceArr(p, offset, UNITS_LEN);
                }
            }
        }
    }

    private function requiredPool() as Array<String> {
        var out = [] as Array<String>;
        appendAll(out, DEFAULT_BASIC_LAYOUT);
        appendAll(out, DEFAULT_SCI_LAYOUT);
        appendAll(out, DEFAULT_ADV_LAYOUT);
        appendAll(out, DEFAULT_VAR_LAYOUT);
        appendAll(out, DEFAULT_UNITS_LAYOUT);
        return out;
    }

    private function appendAll(dst as Array<String>, src as Array<String>) as Void {
        for (var i = 0; i < src.size(); i++) {
            dst.add(src[i]);
        }
    }

    private function sliceArr(src as Array<String>, start as Number, len as Number) as Array<String> {
        var out = [] as Array<String>;
        for (var i = 0; i < len; i++) {
            out.add(src[start + i]);
        }
        return out;
    }

    private function parseColors(s as String) as Array<Number>? {
        var parts = splitStr(s, ",");
        if (parts.size() != 6) {
            return null;
        }
        var out = [] as Array<Number>;
        for (var i = 0; i < parts.size(); i++) {
            var v = hexColor(parts[i]);
            if (v == null) {
                return null;
            }
            out.add(v as Number);
        }
        return out;
    }

    private function hexColor(hex as String) as Number? {
        if (hex.length() != 6) {
            return null;
        }
        var digits = "0123456789abcdef";
        var v = 0;
        for (var j = 0; j < 6; j++) {
            var d = digits.find(hex.substring(j, j + 1).toLower() as String);
            if (d == null) {
                return null;
            }
            v = v * 16 + (d as Number);
        }
        return v;
    }

    private function parseMenu(s as String) as Array<String>? {
        var parts = splitStr(s, ",");
        var out = [] as Array<String>;
        for (var i = 0; i < parts.size(); i++) {
            if (containsStr(VALID_MENU_ITEMS, parts[i]) && !containsStr(out, parts[i])) {
                out.add(parts[i]);
            }
        }
        return out;
    }

    // Must be exactly a permutation of requiredTokens (as a MULTISET - a
    // token repeated N times in requiredTokens, like "c" or "backMenu",
    // must appear exactly N times total, in any of the slots) - every
    // required button once, none missing, none duplicated - or the whole
    // pool is rejected (a partial keypad would strand digits/actions).
    // "blank" is a wildcard: the setup page uses it as "delete this
    // button" - it doesn't need to match anything, it just silently
    // absorbs one leftover required slot so a hidden button doesn't have
    // to reappear somewhere else.
    private function parsePermutation(s as String, requiredTokens as Array<String>) as Array<String>? {
        var parts = splitStr(s, ",");
        if (parts.size() != requiredTokens.size()) {
            return null;
        }
        var remaining = [] as Array<String>;
        for (var ri = 0; ri < requiredTokens.size(); ri++) {
            remaining.add(requiredTokens[ri]);
        }
        for (var i = 0; i < parts.size(); i++) {
            if (parts[i].equals("blank")) {
                if (remaining.size() == 0) {
                    return null;
                }
                remaining.remove(remaining[0]);
                continue;
            }
            var idx = indexOfStr(remaining, parts[i]);
            if (idx == -1) {
                return null;
            }
            remaining.remove(remaining[idx]);
        }
        return parts;
    }

    private function indexOfStr(arr as Array<String>, s as String) as Number {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i].equals(s)) {
                return i;
            }
        }
        return -1;
    }

    private function containsStr(arr as Array<String>, s as String) as Boolean {
        return indexOfStr(arr, s) != -1;
    }

    // Monkey C's String has no built-in split().
    private function splitStr(s as String, delim as String) as Array<String> {
        var out = [] as Array<String>;
        var rest = s;
        while (true) {
            var idx = rest.find(delim);
            if (idx == null) {
                out.add(rest);
                return out;
            }
            out.add(rest.substring(0, idx as Number));
            rest = rest.substring((idx as Number) + delim.length(), rest.length());
        }
        return out;
    }
}

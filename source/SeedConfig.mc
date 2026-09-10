import Toybox.Lang;
import Toybox.Application;

// Parses the compact "1|C=...|M=...|B=..." seed string produced by the
// setup web page (https://giamat13.github.io/calc-for-garmin/) and pasted
// into this app's Connect IQ settings ("calcSeed" property). Anything
// missing, malformed, or from an unknown format version falls back to the
// stock defaults - a bad/partial seed just looks like the plain
// calculator instead of crashing.
class SeedConfig {

    // 6 colors, in order: digit, operator, equals, clear/destructive,
    // nav (MENU/BACK), top display background.
    var colors as Array<Number>;
    // Which tools appear in the MENU screen, and in what order. "Setup"
    // and "BACK" are always appended by the view itself.
    var menuItems as Array<String>;
    // The 20 basic-screen buttons (4 cols x 5 rows, row-major) as short
    // tokens - see VALID_BASIC_TOKENS. Lets the whole basic keypad be
    // rearranged, not just which tools show up in MENU.
    var basicLayout as Array<String>;

    private static var instance as SeedConfig?;

    static const DEFAULT_COLORS = [0x23233A, 0xFFB020, 0x00D68F, 0xFF5470, 0x7C4DFF, 0x14141F] as Array<Number>;
    static const DEFAULT_MENU = ["sci", "units", "tip", "rnd", "var"] as Array<String>;
    static const VALID_MENU_ITEMS = ["sci", "units", "tip", "rnd", "var"] as Array<String>;

    static const DEFAULT_BASIC_LAYOUT = [
        "c", "del", "pct", "div",
        "1", "2", "3", "mul",
        "4", "5", "6", "sub",
        "7", "8", "9", "add",
        "menu", "0", "dot", "eq"
    ] as Array<String>;
    static const VALID_BASIC_TOKENS = [
        "c", "del", "pct", "div", "mul", "sub", "add", "dot", "eq", "menu",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
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
            } else if (f.length() > 2 && f.substring(0, 2).equals("B=")) {
                var parsedLayout = parseBasicLayout(f.substring(2, f.length()));
                if (parsedLayout != null) {
                    basicLayout = parsedLayout as Array<String>;
                }
            }
        }
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

    // Must be exactly a permutation of VALID_BASIC_TOKENS - every required
    // button once, none missing, none duplicated - or the layout is
    // rejected wholesale (a partial keypad would strand digits/actions).
    private function parseBasicLayout(s as String) as Array<String>? {
        var parts = splitStr(s, ",");
        if (parts.size() != VALID_BASIC_TOKENS.size()) {
            return null;
        }
        var remaining = [] as Array<String>;
        for (var ri = 0; ri < VALID_BASIC_TOKENS.size(); ri++) {
            remaining.add(VALID_BASIC_TOKENS[ri]);
        }
        for (var i = 0; i < parts.size(); i++) {
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

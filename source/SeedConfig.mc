import Toybox.Lang;
import Toybox.Application;

// Parses the compact "1|C=rrggbb,...|M=item,..." seed string produced by
// the setup web page (https://giamat13.github.io/calc-for-garmin/) and
// pasted into this app's Connect IQ settings ("calcSeed" property).
// Anything missing, malformed, or from an unknown format version falls
// back to the stock defaults - a bad/partial seed just looks like the
// plain calculator instead of crashing.
class SeedConfig {

    // Order matches the web tool's "C=" field: digit, operator, equals,
    // clear/destructive, nav (MENU/BACK).
    var colors as Array<Number>;
    // Which tools appear in the MENU screen, and in what order. "setup"
    // and "BACK" are always appended by the view itself.
    var menuItems as Array<String>;

    private static var instance as SeedConfig?;

    static const DEFAULT_COLORS = [0x23233A, 0xFFB020, 0x00D68F, 0xFF5470, 0x7C4DFF] as Array<Number>;
    static const DEFAULT_MENU = ["sci", "units", "tip", "rnd", "var"] as Array<String>;
    static const VALID_MENU_ITEMS = ["sci", "units", "tip", "rnd", "var"] as Array<String>;

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
            }
        }
    }

    private function parseColors(s as String) as Array<Number>? {
        var parts = splitStr(s, ",");
        if (parts.size() != 5) {
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

    private function containsStr(arr as Array<String>, s as String) as Boolean {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i].equals(s)) {
                return true;
            }
        }
        return false;
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

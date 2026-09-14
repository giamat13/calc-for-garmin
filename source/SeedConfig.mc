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
// (basic + scientific + advanced + unit-categories, BACK buttons included)
// - 74 tokens total, in fixed screen order. Any token can sit in any slot
// on any screen (every action is self-contained and doesn't care which
// screen it's tapped from), so buttons can be moved between screens, not
// just reordered within one. The whole pool must be an exact permutation
// of the stock 74 - nothing added, removed, or duplicated - or it's
// rejected wholesale and every screen falls back to its own default
// slice. The VAR and NAV screens aren't part of this pool - both are
// fixed, not user-reorderable (see the notes below and VAR_LETTERS/
// navButtons() in calc-for-garminView.mc).
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
    var advLayout as Array<String>;     // 18 tokens, 4 cols x 5 rows (last row uneven)
    var unitsLayout as Array<String>;   // 12 tokens, 3 cols x 4 rows
    // The VAR screen (algebraic letters) isn't here - it's a fixed
    // alphabet, not a customizable slice of the pool (see
    // calc-for-garminView.VAR_LETTERS).

    // Which built-in formula ids (calc-for-garminView.FORMULA_CATALOG) show
    // directly on the FORMULAS screen - anything not listed still exists,
    // just tucked behind its category's "MORE" button. A generated
    // "customN" id (N = index into customFormulas) can appear here too.
    // Independent of the P= pool - it's a variable-length subset pick, not
    // a fixed-grid permutation - so it's its own field ("F=") and adding it
    // needed no SEED version bump (see parseFormulas()).
    var formulaSubset as Array<String>;
    // User-authored formulas from the setup page's custom-formula editor
    // ("U="), each a {label, tpl} pair - tpl is inserted into the
    // expression exactly like a built-in formula's template (see
    // calc-for-garminView.activate()'s "formula:" handling). No device-side
    // limit; the SEED string is the only practical ceiling.
    var customFormulas as Array<Dictionary<String, String> >;

    private static var instance as SeedConfig?;

    static const DEFAULT_COLORS = [0x23233A, 0xFFB020, 0x00D68F, 0xFF5470, 0x7C4DFF, 0x14141F] as Array<Number>;
    // "var"/"apct"/"date" stay VALID (a pasted SEED can still put them
    // directly on MENU) but default off it - they're tucked behind the
    // "MORE" corner button on the Scientific screen instead, to keep the
    // default MENU to the tools used every day. "nav" (cursor/Ans/brackets)
    // is a default MENU item, not tucked away - it's an everyday editing
    // helper, not an occasional tool.
    // Token lists below are comma-joined strings split at load time rather
    // than array literals: every array element costs bytecode, which pushed
    // the app past the 64KB widget limit on older (pre-v2-opcode) watches.
    static const DEFAULT_MENU = "sci,units,tip,rnd,nav";
    // Wrapped in commas so a whole-item match is a single find(",item,").
    static const VALID_MENU_ITEMS = ",sci,units,tip,rnd,var,apct,date,nav,";

    // Kept small on purpose - the rest of calc-for-garminView.FORMULA_CATALOG
    // lives one tap away behind each category's "MORE" button.
    static const DEFAULT_FORMULA_SUBSET = "circleArea,circleCircumference,pythagorean,rectangleArea,speedDistTime";

    static const BASIC_LEN = 20;
    static const SCI_LEN = 24;
    static const ADV_LEN = 18;
    static const UNITS_LEN = 12;

    // 4 cols x 5 rows.
    static const DEFAULT_BASIC_LAYOUT = "c,del,pct,div,1,2,3,mul,4,5,6,sub,7,8,9,add,menu,0,dot,eq";

    // "eqIns" = sci's EQ (inserts "=" to build an equation, distinct from
    // basic's "eq" which evaluates); "backMenu"/"backSci" are BACK buttons
    // - named by destination, not by screen, since the identical action
    // works the same wherever it's placed. 4 cols x 6 rows.
    static const DEFAULT_SCI_LAYOUT = "sin,cos,tan,sqrt,log,ln,sqr,x,open,close,pow,pi,e,c,del,adv,uc,rnd,tip,eqIns,ans,curl,curr,backMenu";

    static const DEFAULT_ADV_LAYOUT = "asin,acos,atan,fact,inv,cbrt,absv,mod,ee,cube,floor,ceil,c,del,pow10,frac,var,backSci";

    static const DEFAULT_UNITS_LAYOUT = "dist,wt,temp,spd,pace,vol,area,time,pres,enrg,cur,backMenu";

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
        menuItems = splitStr(DEFAULT_MENU, ",");
        basicLayout = splitStr(DEFAULT_BASIC_LAYOUT, ",");
        sciLayout = splitStr(DEFAULT_SCI_LAYOUT, ",");
        advLayout = splitStr(DEFAULT_ADV_LAYOUT, ",");
        unitsLayout = splitStr(DEFAULT_UNITS_LAYOUT, ",");
        formulaSubset = splitStr(DEFAULT_FORMULA_SUBSET, ",");
        customFormulas = [] as Array<Dictionary<String, String> >;
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
                    unitsLayout = sliceArr(p, offset, UNITS_LEN);
                }
            } else if (f.length() >= 2 && f.substring(0, 2).equals("F=")) {
                formulaSubset = parseFormulas(f.substring(2, f.length()));
            } else if (f.length() >= 2 && f.substring(0, 2).equals("U=")) {
                customFormulas = parseCustomFormulas(f.substring(2, f.length()));
            }
        }
    }

    private function requiredPool() as Array<String> {
        return splitStr(DEFAULT_BASIC_LAYOUT + "," + DEFAULT_SCI_LAYOUT + "," + DEFAULT_ADV_LAYOUT + "," + DEFAULT_UNITS_LAYOUT, ",");
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
            if (VALID_MENU_ITEMS.find("," + parts[i] + ",") != null && !containsStr(out, parts[i])) {
                out.add(parts[i]);
            }
        }
        return out;
    }

    // Unlike parseMenu(), there's no fixed whitelist to check against here
    // - the valid id set is built-in formulas PLUS however many custom
    // ones this same seed defines via "U=", which calc-for-garminView
    // resolves at render time. An id that doesn't resolve to anything is
    // just silently skipped when the FORMULAS screen is built - same
    // "ignore what you don't recognize" tolerance as the rest of this
    // parser - so this only needs to dedupe and drop empties.
    private function parseFormulas(s as String) as Array<String> {
        var out = [] as Array<String>;
        if (s.length() == 0) {
            return out;
        }
        var parts = splitStr(s, ",");
        for (var i = 0; i < parts.size(); i++) {
            if (parts[i].length() > 0 && !containsStr(out, parts[i])) {
                out.add(parts[i]);
            }
        }
        return out;
    }

    // "label~template;label~template;..." - the setup page's custom-
    // formula editor sanitizes both halves to strip "|", ";", and "~"
    // before building the seed, so no escaping is needed here. A malformed
    // entry (missing "~", or an empty half) is just dropped.
    private function parseCustomFormulas(s as String) as Array<Dictionary<String, String> > {
        var out = [] as Array<Dictionary<String, String> >;
        if (s.length() == 0) {
            return out;
        }
        var entries = splitStr(s, ";");
        for (var i = 0; i < entries.size(); i++) {
            var entry = entries[i];
            var sepIdx = entry.find("~");
            if (sepIdx == null) {
                continue;
            }
            var label = entry.substring(0, sepIdx as Number) as String;
            var tpl = entry.substring((sepIdx as Number) + 1, entry.length()) as String;
            if (label.length() == 0 || tpl.length() == 0) {
                continue;
            }
            out.add({"label" => label, "tpl" => tpl} as Dictionary<String, String>);
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

}

// Monkey C's String has no built-in split().
function splitStr(s as String, delim as String) as Array<String> {
    var out = [] as Array<String>;
    var rest = s;
    while (true) {
        var idx = rest.find(delim);
        if (idx == null) {
            out.add(rest);
            return out;
        }
        out.add(rest.substring(0, idx as Number) as String);
        rest = rest.substring((idx as Number) + delim.length(), rest.length()) as String;
    }
    return out;
}

// Looks up `key` in a ",key~a~b,key2~c," table and returns its fields
// (["a","b"]), or null if absent. The table's first character is its row
// separator and it must also end with one ("," here; "|" for a table whose
// values contain commas). Used instead of long if/else-equals chains or
// dictionary literals, which compile to far more bytecode on older watches.
function specLookup(spec as String, key as String) as Array<String>? {
    var sep = spec.substring(0, 1) as String;
    var i = spec.find(sep + key + "~");
    if (i == null) {
        return null;
    }
    var rest = spec.substring((i as Number) + key.length() + 2, spec.length()) as String;
    return splitStr(rest.substring(0, rest.find(sep) as Number) as String, "~");
}

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
    // and "BACK" are always appended by the view itself. Lazy, same
    // reasoning as the layout fields below.
    private var _menuItems as Array<String>?;
    // Per-screen slices of the pool - see class comment. Backing fields are
    // lazy (null until first touched) so a fresh launch only pays for
    // splitting the ONE screen actually shown first, not all 4 - real
    // pressure on the smallest watches (see the pool comment above).
    private var _basicLayout as Array<String>?;   // 20 tokens, 4 cols x 5 rows
    private var _sciLayout as Array<String>?;     // 24 tokens, 4 cols x 6 rows
    private var _advLayout as Array<String>?;     // 18 tokens, 4 cols x 5 rows (last row uneven)
    private var _unitsLayout as Array<String>?;   // 12 tokens, 3 cols x 4 rows
    // The VAR screen (algebraic letters) isn't here - it's a fixed
    // alphabet, not a customizable slice of the pool (see
    // calc-for-garminView.VAR_LETTERS).


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
            instance = new SeedConfig(readProp("calcSeed") as String?);
        }
        return instance as SeedConfig;
    }

    // Re-parses from Properties - call after the phone's Settings UI may
    // have changed them (App.onSettingsChanged).
    static function reload() as Void {
        instance = new SeedConfig(readProp("calcSeed") as String?);
    }

    function initialize(seed as String?) {
        colors = DEFAULT_COLORS;
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
                    _menuItems = parsedMenu as Array<String>;
                }
            } else if (f.length() > 2 && f.substring(0, 2).equals("P=")) {
                var pool = parsePermutation(f.substring(2, f.length()), requiredPool());
                if (pool != null) {
                    var p = pool as Array<String>;
                    var offset = 0;
                    _basicLayout = sliceArr(p, offset, BASIC_LEN); offset += BASIC_LEN;
                    _sciLayout = sliceArr(p, offset, SCI_LEN); offset += SCI_LEN;
                    _advLayout = sliceArr(p, offset, ADV_LEN); offset += ADV_LEN;
                    _unitsLayout = sliceArr(p, offset, UNITS_LEN);
                }
            }
        }
    }

    function menuItems() as Array<String> {
        if (_menuItems == null) {
            _menuItems = splitStr(DEFAULT_MENU, ",");
        }
        return _menuItems as Array<String>;
    }

    // Each screen's layout is only split from its default the first time
    // it's actually shown (see the lazy backing fields above) - a P= seed
    // already filled the backing field eagerly in initialize() above, so
    // these just return it unchanged in that case.
    function basicLayout() as Array<String> {
        if (_basicLayout == null) {
            _basicLayout = splitStr(DEFAULT_BASIC_LAYOUT, ",");
        }
        return _basicLayout as Array<String>;
    }

    function sciLayout() as Array<String> {
        if (_sciLayout == null) {
            _sciLayout = splitStr(DEFAULT_SCI_LAYOUT, ",");
        }
        return _sciLayout as Array<String>;
    }

    function advLayout() as Array<String> {
        if (_advLayout == null) {
            _advLayout = splitStr(DEFAULT_ADV_LAYOUT, ",");
        }
        return _advLayout as Array<String>;
    }

    function unitsLayout() as Array<String> {
        if (_unitsLayout == null) {
            _unitsLayout = splitStr(DEFAULT_UNITS_LAYOUT, ",");
        }
        return _unitsLayout as Array<String>;
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

// API < 2.4 watches (fenix3, fr230, vivoactive, ...) have neither
// Application.Properties nor Application.Storage - both fall back to the
// old AppBase property store there.
function readProp(key as String) as PropertyValueType? {
    if (Application has :Properties) {
        return Application.Properties.getValue(key);
    }
    return Application.getApp().getProperty(key);
}

function readStore(key as String) as PropertyValueType? {
    if (Application has :Storage) {
        return Application.Storage.getValue(key);
    }
    return Application.getApp().getProperty(key);
}

function writeStore(key as String, value as PropertyValueType) as Void {
    if (Application has :Storage) {
        Application.Storage.setValue(key, value);
    } else {
        Application.getApp().setProperty(key, value);
    }
}

// Monkey C's String has no built-in split().
function splitStr(s as String, delim as String) as Array<String> {
    // Scans by index instead of re-copying an ever-shrinking "rest" tail on
    // every delimiter (that was O(n^2) transient garbage for a string with
    // many fields - real pressure on the smallest watches).
    var out = [] as Array<String>;
    var len = s.length();
    var dlen = delim.length();
    var start = 0;
    var i = 0;
    while (i <= len - dlen) {
        if ((s.substring(i, i + dlen) as String).equals(delim)) {
            out.add(s.substring(start, i) as String);
            i += dlen;
            start = i;
        } else {
            i++;
        }
    }
    out.add(s.substring(start, len) as String);
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
    // Scans forward from the match for the row's closing separator instead
    // of substring-ing everything from the match to the END of `spec` (the
    // old `rest = spec.substring(i, spec.length())` copied up to the whole
    // table on every lookup - real pressure on the smallest watches when
    // the match is near the front of a long spec).
    var start = (i as Number) + key.length() + 2;
    var len = spec.length();
    var j = start;
    while (j < len && !(spec.substring(j, j + 1) as String).equals(sep)) {
        j++;
    }
    return splitStr(spec.substring(start, j) as String, "~");
}

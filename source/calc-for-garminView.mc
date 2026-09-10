import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Communications;
import Toybox.Application.Storage;
import Toybox.Math;

class CalcButton {
    var label as String;
    var action as String;
    var x as Number = 0;
    var y as Number = 0;
    var w as Number = 0;
    var h as Number = 0;
    // SVG icon (see Icons.mc), loaded per layout; null draws the label.
    var icon as WatchUi.BitmapResource? = null;

    function initialize(label as String, action as String) {
        me.label = label;
        me.action = action;
    }

    function contains(px as Number, py as Number) as Boolean {
        return px >= x && px <= x + w && py >= y && py <= y + h;
    }
}

class calc_for_garminView extends WatchUi.View {

    const SCREEN_BASIC = 0;
    const SCREEN_SCIENTIFIC = 1;
    const SCREEN_ADVANCED = 2;
    const SCREEN_UNITS = 3;       // category picker: weight / distance / temp / ...
    const SCREEN_UNIT_PICK = 4;   // unit picker for the chosen category
    const SCREEN_CUR_LETTER = 5;  // currency autocomplete: pick a first letter
    const SCREEN_CUR_RESULTS = 6; // currency autocomplete: matching codes for that letter
    const SCREEN_RANDOM = 7;      // random number generator: pick a range, then roll
    const SCREEN_TIP = 8;         // tip & bill split: bill, tip %, people -> each
    const SCREEN_VAR = 9;         // named variables: store/recall A/B/C/D
    const SCREEN_MENU = 10;       // tool hub: jump straight to any advanced tool

    // Random/tip/unit-conversion are "embedded flows": the expression being
    // built (e.g. "1+") is stashed here while a temporary value is entered
    // on a different screen, then the flow's result is spliced back in at
    // the same cursor position - e.g. "1+" -> RND -> "1+7". Null when no
    // such flow is in progress. See enterEmbeddedFlow()/exitEmbeddedFlow().
    private var pendingExpr as String? = null;
    private var pendingCursor as Number = 0;

    var engine as CalculatorEngine = new CalculatorEngine();
    var screen as Number = SCREEN_BASIC;
    var selectedIndex as Number = 0;
    private var buttons as Array<CalcButton> = [] as Array<CalcButton>;

    // Two-step unit conversion state: first tap picks the source unit
    // (highlighted), second tap on a different unit performs the conversion.
    private var unitCategory as String = "";
    private var fromUnitKey as String? = null;

    // Currency conversion: rates are USD-based (1 USD = rate[code] units of
    // that currency). Falls back to the last successfully fetched rates
    // (persisted in Storage), or to this hardcoded table on first-ever use
    // with no internet and no stored rates.
    const CURRENCY_KEYS = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"] as Array<String>;
    const DEFAULT_CURRENCY_RATES = {
        "USD" => 1.0d,
        "EUR" => 0.92d,
        "GBP" => 0.79d,
        "JPY" => 149.5d,
        "CAD" => 1.36d,
        "AUD" => 1.52d,
    } as Dictionary<String, Double>;
    private var currencyRates as Dictionary<String, Double> = DEFAULT_CURRENCY_RATES;

    // Currency autocomplete: after picking a first letter, the matching
    // codes for it are shown as buttons on SCREEN_CUR_RESULTS.
    private var curMatches as Array<String> = [] as Array<String>;

    // Random number generator state. randStage: 0 = entering MIN, 1 =
    // entering MAX. Bounds are stored as whatever was typed (via the
    // engine's own expression parser, so "3+4" or "-5" work), then rounded
    // to whole numbers when rolling. GEN immediately splices the roll back
    // into the pending expression (see enterEmbeddedFlow()).
    private var randStage as Number = 0;
    private var randMin as Double = 0.0d;
    private var randMax as Double = 0.0d;

    // Tip/split state. tipStage: 0 = BILL, 1 = TIP %, 2 = PEOPLE. GO
    // immediately splices the per-person amount into the pending expression.
    private var tipStage as Number = 0;
    private var tipBill as Double = 0.0d;
    private var tipPct as Double = 0.0d;

    // Safe content area: on round watches a full-width row near the top/bottom
    // edge gets chopped off by the bezel, so content is confined to the
    // largest square that is guaranteed to stay inside the circle.
    private var safeX as Number = 0;
    private var safeY as Number = 0;
    private var safeW as Number = 0;
    private var safeH as Number = 0;

    function initialize() {
        View.initialize();
        var stored = Storage.getValue("currencyRates");
        if (stored != null) {
            currencyRates = stored as Dictionary<String, Double>;
        }
    }

    // Best-effort background refresh; whatever's already in currencyRates
    // (fetched-and-stored, or the hardcoded default) keeps being used for
    // conversions until/unless this succeeds.
    private function refreshCurrencyRates() as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        Communications.makeWebRequest("https://open.er-api.com/v6/latest/USD", null, options, method(:onCurrencyRatesResponse));
    }

    function onCurrencyRatesResponse(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200 || data == null) {
            return;
        }
        var body = data as Dictionary;
        var rates = body["rates"];
        if (rates == null) {
            return;
        }
        rates = rates as Dictionary;
        // Store every currency the API knows about, not just the quick-pick
        // shortcuts, so "OTHER" autocomplete can reach any of them.
        var rateKeys = (rates as Dictionary).keys();
        var fresh = {} as Dictionary<String, Double>;
        for (var i = 0; i < rateKeys.size(); i++) {
            var key = rateKeys[i] as String;
            var r = rates[key];
            if (r != null) {
                fresh[key] = (r as Numeric).toDouble();
            }
        }
        if (fresh.size() == 0) {
            return;
        }
        currencyRates = fresh;
        Storage.setValue("currencyRates", fresh);
        // Rebuild buttons too: a letter screen opened before the fetch landed
        // would otherwise keep showing only the default codes' letters.
        layoutButtons();
        WatchUi.requestUpdate();
    }

    // Test-only hook to make currency conversion deterministic without
    // depending on Storage or network state.
    function setCurrencyRatesForTest(rates as Dictionary<String, Double>) as Void {
        currencyRates = rates;
    }

    function onLayout(dc as Dc) as Void {
        var isRound = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        layoutForSize(dc.getWidth(), dc.getHeight(), isRound);
    }

    function onShow() as Void {
    }

    // Split out from onLayout() so layout math can be unit-tested with
    // plain numbers instead of a real Dc.
    function layoutForSize(width as Number, height as Number, isRound as Boolean) as Void {
        computeSafeArea(width, height, isRound);
        layoutButtons();
    }

    private function computeSafeArea(width as Number, height as Number, isRound as Boolean) as Void {
        if (isRound) {
            var side = (width < height ? width : height) * 0.72;
            safeW = side.toNumber();
            safeH = safeW;
            safeX = (width - safeW) / 2;
            safeY = (height - safeH) / 2;
        } else {
            safeX = 0;
            safeY = 0;
            safeW = width;
            safeH = height;
        }
    }

    // Home screen: a plain, familiar 4-function calculator - digits, the
    // four operators, %, C/DEL and "=". No cursor arrows, parens, Ans or
    // variables here; those live one tap away on the Scientific screen via
    // MENU, so someone who only ever wants basic arithmetic never sees them.
    // 4 cols x 5 rows.
    private function basicButtons() as Array<CalcButton> {
        return [
            new CalcButton("C", "clear"), new CalcButton("DEL", "back"), new CalcButton("%", "op:%"), new CalcButton("/", "op:/"),
            new CalcButton("1", "digit:1"), new CalcButton("2", "digit:2"), new CalcButton("3", "digit:3"), new CalcButton("*", "op:*"),
            new CalcButton("4", "digit:4"), new CalcButton("5", "digit:5"), new CalcButton("6", "digit:6"), new CalcButton("-", "op:-"),
            new CalcButton("7", "digit:7"), new CalcButton("8", "digit:8"), new CalcButton("9", "digit:9"), new CalcButton("+", "op:+"),
            new CalcButton("MENU", "menu"), new CalcButton("0", "digit:0"), new CalcButton(".", "digit:."), new CalcButton("=", "equals"),
        ] as Array<CalcButton>;
    }

    // Tool hub: every advanced tool is one tap away from here instead of
    // paged through in sequence. 2 cols x 3 rows.
    private function menuButtons() as Array<CalcButton> {
        return [
            new CalcButton("fx", "sci"), new CalcButton("Units", "units"),
            new CalcButton("Tip", "tip"), new CalcButton("RND", "random"),
            new CalcButton("VAR", "var"), new CalcButton("BACK", "basic"),
        ] as Array<CalcButton>;
    }

    // Scientific screen: functions, parentheses, general powers, cursor
    // movement and Ans (relocated here from the old basic screen), plus EQ
    // for building equations, 4 cols x 6 rows.
    private function scientificButtons() as Array<CalcButton> {
        return [
            new CalcButton("sin", "func:sin"), new CalcButton("cos", "func:cos"), new CalcButton("tan", "func:tan"), new CalcButton("sqrt", "func:sqrt"),
            new CalcButton("log", "func:log"), new CalcButton("ln", "func:ln"), new CalcButton("x2", "sqr"), new CalcButton("x", "const:X"),
            new CalcButton("(", "open"), new CalcButton(")", "close"), new CalcButton("^", "op:^"), new CalcButton("pi", "const:π"),
            new CalcButton("e", "const:e"), new CalcButton("C", "clear"), new CalcButton("DEL", "back"), new CalcButton("ADV", "adv"),
            new CalcButton("BACK", "menu"), new CalcButton("UC", "units"), new CalcButton("RND", "random"), new CalcButton("TIP", "tip"),
            new CalcButton("EQ", "eq"), new CalcButton("Ans", "ans"), new CalcButton("<", "curLeft"), new CalcButton(">", "curRight"),
        ] as Array<CalcButton>;
    }

    // Advanced screen: inverse trig, roots, integer/rounding ops and the
    // ×10^x shortcut for entering numbers in scientific notation, 4 cols x 5 rows.
    private function advancedButtons() as Array<CalcButton> {
        return [
            new CalcButton("asin", "func:asin"), new CalcButton("acos", "func:acos"), new CalcButton("atan", "func:atan"), new CalcButton("x!", "fact"),
            new CalcButton("1/x", "inv"), new CalcButton("cbrt", "func:cbrt"), new CalcButton("|x|", "func:abs"), new CalcButton("mod", "op:mod"),
            new CalcButton("EE", "ee"), new CalcButton("x3", "cube"), new CalcButton("floor", "func:floor"), new CalcButton("ceil", "func:ceil"),
            new CalcButton("C", "clear"), new CalcButton("DEL", "back"), new CalcButton("10x", "pow10"), new CalcButton("VAR", "var"),
            new CalcButton("BACK", "sci"),
        ] as Array<CalcButton>;
    }

    // Named-variable screen: store the currently typed value under A/B/C/D,
    // or recall one back into the expression at the cursor. 2 cols x 5 rows.
    private function varButtons() as Array<CalcButton> {
        var defs = [] as Array<CalcButton>;
        var names = ["A", "B", "C", "D"];
        for (var i = 0; i < names.size(); i++) {
            defs.add(new CalcButton("STO " + names[i], "sto:" + names[i]));
            defs.add(new CalcButton("RCL " + names[i], "rcl:" + names[i]));
        }
        defs.add(new CalcButton("CLR", "varClear"));
        defs.add(new CalcButton("BACK", "varBack"));
        return defs;
    }

    // Step 1 of the unit converter: pick WHAT to measure. 3 cols x 4 rows.
    private function unitCategoryButtons() as Array<CalcButton> {
        return [
            new CalcButton("DIST",  "cat:dist"),
            new CalcButton("WT",    "cat:weight"),
            new CalcButton("TEMP",  "cat:temp"),
            new CalcButton("SPD",   "cat:speed"),
            new CalcButton("PACE",  "cat:pace"),
            new CalcButton("VOL",   "cat:vol"),
            new CalcButton("AREA",  "cat:area"),
            new CalcButton("TIME",  "cat:time"),
            new CalcButton("PRES",  "cat:pres"),
            new CalcButton("ENRG",  "cat:energy"),
            new CalcButton("CUR",   "cat:cur"),
            new CalcButton("BACK",  "menu"),
        ] as Array<CalcButton>;
    }

    // The unit keys that belong to each measurement category, in display order.
    private function unitKeysFor(category as String) as Array<String> {
        if (category.equals("dist")) {
            return ["km", "mi", "m", "ft", "cm", "in", "yd", "NM"] as Array<String>;
        } else if (category.equals("weight")) {
            return ["kg", "g", "lb", "oz", "st"] as Array<String>;
        } else if (category.equals("temp")) {
            return ["c", "f", "K"] as Array<String>;
        } else if (category.equals("speed")) {
            return ["kph", "mph", "m/s", "kn"] as Array<String>;
        } else if (category.equals("pace")) {
            return ["/km", "/mi", "kph", "mph"] as Array<String>;
        } else if (category.equals("vol")) {
            return ["l", "mL", "gal", "cup", "floz"] as Array<String>;
        } else if (category.equals("area")) {
            return ["m2", "km2", "ha", "acre", "ft2", "mi2"] as Array<String>;
        } else if (category.equals("time")) {
            return ["sec", "min", "hr", "day", "wk"] as Array<String>;
        } else if (category.equals("pres")) {
            return ["bar", "kPa", "hPa", "psi", "atm", "mmHg"] as Array<String>;
        } else if (category.equals("energy")) {
            return ["kcal", "kJ", "kWh"] as Array<String>;
        } else if (category.equals("cur")) {
            return CURRENCY_KEYS;
        }
        return [] as Array<String>;
    }

    // Compact integer display for the random screen's MIN/MAX hints.
    private function formatWhole(v as Double) as String {
        return ((Math.round(v) as Numeric).toNumber()).toString();
    }

    private function unitLabel(key as String) as String {
        if (key.equals("km")) { return "km"; }
        else if (key.equals("mi")) { return "mi"; }
        else if (key.equals("m")) { return "m"; }
        else if (key.equals("ft")) { return "ft"; }
        else if (key.equals("cm")) { return "cm"; }
        else if (key.equals("in")) { return "in"; }
        else if (key.equals("kg")) { return "kg"; }
        else if (key.equals("lb")) { return "lb"; }
        else if (key.equals("c")) { return "°C"; }
        else if (key.equals("f")) { return "°F"; }
        else if (key.equals("kph")) { return "kph"; }
        else if (key.equals("mph")) { return "mph"; }
        else if (key.equals("l")) { return "L"; }
        else if (key.equals("gal")) { return "gal"; }
        return key;
    }

    // Step 2 of the unit converter: pick the source unit, then the target
    // unit (handled two-tap in activate()/handleUnitTap()). 2 cols, rows
    // sized to whatever the category needs.
    private function unitPickButtons() as Array<CalcButton> {
        var keys = unitKeysFor(unitCategory);
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < keys.size(); i++) {
            defs.add(new CalcButton(unitLabel(keys[i]), "unit:" + keys[i]));
        }
        // Currency has far more codes than fit on screen at once, so beyond
        // the quick-pick shortcuts, OTHER opens a letter-narrowed search
        // over every code the last successful rate fetch returned.
        if (unitCategory.equals("cur")) {
            defs.add(new CalcButton("OTHER", "curOther"));
        }
        defs.add(new CalcButton("C", "clear"));
        defs.add(new CalcButton("BACK", "unitCatBack"));
        return defs;
    }

    // Array.sort() is CIQ 3.4.0+; vivoactive 4s and friends cap at 3.3, so
    // sorting there throws Symbol Not Found. Insertion sort over char codes
    // instead - the lists here are letters and currency codes, tens of items.
    private function sortStrings(arr as Array<String>) as Array<String> {
        for (var i = 1; i < arr.size(); i++) {
            var v = arr[i];
            var j = i - 1;
            while (j >= 0 && stringLess(v, arr[j])) {
                arr[j + 1] = arr[j];
                j--;
            }
            arr[j + 1] = v;
        }
        return arr;
    }

    private function stringLess(a as String, b as String) as Boolean {
        var ca = a.toCharArray();
        var cb = b.toCharArray();
        var n = ca.size() < cb.size() ? ca.size() : cb.size();
        for (var i = 0; i < n; i++) {
            var da = ca[i].toNumber();
            var db = cb[i].toNumber();
            if (da != db) {
                return da < db;
            }
        }
        return ca.size() < cb.size();
    }

    // First letters of every known currency code, sorted, for the
    // autocomplete letter screen.
    private function currencyLetters() as Array<String> {
        var seen = {} as Dictionary<String, Boolean>;
        var letters = [] as Array<String>;
        var keys = currencyRates.keys();
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i] as String;
            if (k.length() == 0) {
                continue;
            }
            var letter = k.substring(0, 1) as String;
            if (!seen.hasKey(letter)) {
                seen[letter] = true;
                letters.add(letter);
            }
        }
        return sortStrings(letters);
    }

    private function curLetterButtons() as Array<CalcButton> {
        var letters = currencyLetters();
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < letters.size(); i++) {
            defs.add(new CalcButton(letters[i], "curletter:" + letters[i]));
        }
        defs.add(new CalcButton("BACK", "curLetterBack"));
        return defs;
    }

    // Currency codes starting with the chosen letter; reuses the same
    // "unit:" action as the quick-pick buttons, so selecting one feeds
    // straight back into handleUnitTap()'s two-step FROM/TO flow.
    private function currencyCodesStartingWith(prefix as String) as Array<String> {
        var out = [] as Array<String>;
        var keys = currencyRates.keys();
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i] as String;
            if (k.find(prefix) == 0) {
                out.add(k);
            }
        }
        return sortStrings(out);
    }

    private function curResultButtons() as Array<CalcButton> {
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < curMatches.size(); i++) {
            defs.add(new CalcButton(curMatches[i], "unit:" + curMatches[i]));
        }
        defs.add(new CalcButton("BACK", "curResultsBack"));
        return defs;
    }

    // Random screen: a compact numeric keypad for typing MIN then MAX
    // (reuses the same "digit:"/"op:-"/"back"/"clear" actions the main
    // keypad already handles). GEN splices the roll straight into whatever
    // expression was being built and returns to it - see enterEmbeddedFlow().
    private function randomButtons() as Array<CalcButton> {
        return keypadButtons("randBack", randStage == 0 ? "NEXT" : "GEN", randStage == 0 ? "randNext" : "randGen");
    }

    // Tip screen: same keypad for BILL / TIP % / PEOPLE. GO splices the
    // per-person amount back into the pending expression.
    private function tipButtons() as Array<CalcButton> {
        return keypadButtons("tipBack", tipStage == 2 ? "GO" : "NEXT", tipStage == 2 ? "tipGo" : "tipNext");
    }

    // Compact 4x4 numeric keypad shared by the random and tip screens.
    private function keypadButtons(backAction as String, nextLabel as String, nextAction as String) as Array<CalcButton> {
        var defs = [] as Array<CalcButton>;
        defs.add(new CalcButton("7", "digit:7"));
        defs.add(new CalcButton("8", "digit:8"));
        defs.add(new CalcButton("9", "digit:9"));
        defs.add(new CalcButton("DEL", "back"));
        defs.add(new CalcButton("4", "digit:4"));
        defs.add(new CalcButton("5", "digit:5"));
        defs.add(new CalcButton("6", "digit:6"));
        defs.add(new CalcButton("C", "clear"));
        defs.add(new CalcButton("1", "digit:1"));
        defs.add(new CalcButton("2", "digit:2"));
        defs.add(new CalcButton("3", "digit:3"));
        defs.add(new CalcButton("-", "op:-"));
        defs.add(new CalcButton("0", "digit:0"));
        defs.add(new CalcButton(".", "digit:."));
        defs.add(new CalcButton("BACK", backAction));
        defs.add(new CalcButton(nextLabel, nextAction));
        return defs;
    }

    private function layoutButtons() as Void {
        var defs = basicButtons();
        var cols = 4;
        var rows = 5;
        if (screen == SCREEN_SCIENTIFIC) {
            defs = scientificButtons();
            cols = 4;
            rows = 6;
        } else if (screen == SCREEN_ADVANCED) {
            defs = advancedButtons();
            cols = 4;
            rows = 5;
        } else if (screen == SCREEN_UNITS) {
            defs = unitCategoryButtons();
            cols = 3;
            rows = 4;
        } else if (screen == SCREEN_UNIT_PICK) {
            defs = unitPickButtons();
            // Big categories (distance, currency) would need 5+ rows of 2.
            cols = defs.size() > 8 ? 3 : 2;
            rows = (defs.size() + cols - 1) / cols;
        } else if (screen == SCREEN_CUR_LETTER) {
            defs = curLetterButtons();
            cols = 5;
            rows = (defs.size() + cols - 1) / cols;
        } else if (screen == SCREEN_CUR_RESULTS) {
            defs = curResultButtons();
            cols = 2;
            rows = (defs.size() + cols - 1) / cols;
        } else if (screen == SCREEN_RANDOM) {
            defs = randomButtons();
            cols = 4;
            rows = (defs.size() + cols - 1) / cols;
        } else if (screen == SCREEN_TIP) {
            defs = tipButtons();
            cols = 4;
            rows = (defs.size() + cols - 1) / cols;
        } else if (screen == SCREEN_VAR) {
            defs = varButtons();
            cols = 2;
            rows = (defs.size() + cols - 1) / cols;
        } else if (screen == SCREEN_MENU) {
            defs = menuButtons();
            cols = 2;
            rows = 3;
        }

        // BACK always lands in the grid's bottom-right corner, regardless of
        // how many other buttons come before it or whether the last row is
        // fully packed - otherwise its position shifts from screen to
        // screen, which is what made it confusing to find.
        var backBtn = null as CalcButton?;
        var others = [] as Array<CalcButton>;
        for (var oi = 0; oi < defs.size(); oi++) {
            if (backBtn == null && defs[oi].label.equals("BACK")) {
                backBtn = defs[oi];
            } else {
                others.add(defs[oi]);
            }
        }

        var headerH = (safeH * 0.24).toNumber();
        var gridTop = safeY + headerH;
        var gridH = safeH - headerH;
        var cellW = safeW / cols;
        var cellH = gridH / rows;

        for (var i = 0; i < others.size(); i++) {
            var row = i / cols;
            var col = i % cols;
            var b = others[i];
            b.x = safeX + col * cellW;
            b.y = gridTop + row * cellH;
            b.w = cellW;
            b.h = cellH;
            var iconId = iconFor(b.action, b.label);
            if (iconId != null) {
                b.icon = WatchUi.loadResource(iconId) as WatchUi.BitmapResource;
            }
        }
        if (backBtn != null) {
            var b = backBtn as CalcButton;
            b.x = safeX + (cols - 1) * cellW;
            b.y = gridTop + (rows - 1) * cellH;
            b.w = cellW;
            b.h = cellH;
            var iconId = iconFor(b.action, b.label);
            if (iconId != null) {
                b.icon = WatchUi.loadResource(iconId) as WatchUi.BitmapResource;
            }
            others.add(b);
        }
        buttons = others;
        if (selectedIndex >= buttons.size()) {
            selectedIndex = 0;
        }
    }

    function getButtons() as Array<CalcButton> {
        return buttons;
    }

    // Index of the button under (x,y), or null if the tap missed every button.
    function buttonAt(x as Number, y as Number) as Number? {
        for (var i = 0; i < buttons.size(); i++) {
            if (buttons[i].contains(x, y)) {
                return i;
            }
        }
        return null;
    }

    function switchScreen(newScreen as Number) as Void {
        // Leaving to a "real" calculator screen exits any embedded flow
        // (random/tip/unit conversion) still in progress; a successful
        // completion already called exitEmbeddedFlow() itself before
        // getting here, so this is then a no-op (pendingExpr is null).
        if (pendingExpr != null && (newScreen == SCREEN_BASIC || newScreen == SCREEN_SCIENTIFIC || newScreen == SCREEN_ADVANCED)) {
            exitEmbeddedFlow(null);
        }
        screen = newScreen;
        selectedIndex = 0;
        fromUnitKey = null;
        layoutButtons();
    }

    // Stashes the expression being built so a temporary value can be typed
    // on another screen (random range, tip inputs, a value to convert)
    // without losing it; see exitEmbeddedFlow().
    private function enterEmbeddedFlow() as Void {
        pendingExpr = engine.expr;
        pendingCursor = engine.cursorPos;
        engine.clear();
    }

    // Restores the expression stashed by enterEmbeddedFlow(), optionally
    // splicing text in at the point where the flow was entered. A no-op if
    // no flow is in progress (so it's safe to call unconditionally on any
    // "exit" action).
    private function exitEmbeddedFlow(insertText as String?) as Void {
        if (pendingExpr == null) {
            return;
        }
        engine.expr = pendingExpr as String;
        engine.cursorPos = pendingCursor;
        if (insertText != null) {
            engine.insertRaw(insertText as String);
        }
        pendingExpr = null;
    }

    // Like switchScreen, but keeps fromUnitKey/unitCategory - used to
    // navigate within the currency autocomplete flow (letter -> results ->
    // back to the unit picker) without losing an in-progress FROM/TO pick.
    function goToScreen(newScreen as Number) as Void {
        screen = newScreen;
        selectedIndex = 0;
        layoutButtons();
    }

    function moveSelection(delta as Number) as Void {
        if (buttons.size() == 0) {
            return;
        }
        selectedIndex = (selectedIndex + delta + buttons.size()) % buttons.size();
    }

    function activate(b as CalcButton) as Void {
        var action = b.action;
        if (action.equals("clear")) {
            engine.clear();
            fromUnitKey = null;
            return;
        } else if (action.equals("back")) {
            engine.backspace();
            return;
        } else if (action.equals("equals")) {
            engine.evaluate();
            return;
        } else if (action.equals("sci")) {
            switchScreen(SCREEN_SCIENTIFIC);
            return;
        } else if (action.equals("basic")) {
            switchScreen(SCREEN_BASIC);
            return;
        } else if (action.equals("menu")) {
            switchScreen(SCREEN_MENU);
            return;
        } else if (action.equals("adv")) {
            switchScreen(SCREEN_ADVANCED);
            return;
        } else if (action.equals("units")) {
            enterEmbeddedFlow();
            switchScreen(SCREEN_UNITS);
            return;
        } else if (action.equals("unitCatBack")) {
            switchScreen(SCREEN_UNITS);
            return;
        } else if (action.equals("curLeft")) {
            engine.moveCursorLeft();
            return;
        } else if (action.equals("curRight")) {
            engine.moveCursorRight();
            return;
        } else if (action.equals("ans")) {
            engine.insertAns();
            return;
        } else if (action.equals("eq")) {
            engine.insertEquals();
            return;
        } else if (action.equals("var")) {
            switchScreen(SCREEN_VAR);
            return;
        } else if (action.equals("varBack")) {
            switchScreen(SCREEN_MENU);
            return;
        } else if (action.equals("varClear")) {
            engine.clearVariables();
            return;
        } else if (action.equals("open")) {
            engine.openParen();
            return;
        } else if (action.equals("close")) {
            engine.closeParen();
            return;
        } else if (action.equals("sqr")) {
            engine.wrapSquare();
            return;
        } else if (action.equals("cube")) {
            engine.wrapCube();
            return;
        } else if (action.equals("inv")) {
            engine.wrapInverse();
            return;
        } else if (action.equals("pow10")) {
            engine.wrapPow10();
            return;
        } else if (action.equals("fact")) {
            engine.wrapFactorial();
            return;
        } else if (action.equals("ee")) {
            engine.appendRaw("*10^");
            return;
        } else if (action.equals("curOther")) {
            goToScreen(SCREEN_CUR_LETTER);
            return;
        } else if (action.equals("curLetterBack")) {
            goToScreen(SCREEN_UNIT_PICK);
            return;
        } else if (action.equals("curResultsBack")) {
            goToScreen(SCREEN_CUR_LETTER);
            return;
        } else if (action.equals("random")) {
            enterEmbeddedFlow();
            randStage = 0;
            randMin = 0.0d;
            randMax = 0.0d;
            switchScreen(SCREEN_RANDOM);
            return;
        } else if (action.equals("randNext")) {
            var minOrNull = readEntry();
            if (minOrNull == null) {
                return;
            }
            randMin = minOrNull as Double;
            engine.clear();
            goToRandomStage(1);
            return;
        } else if (action.equals("randGen")) {
            var maxOrNull = readEntry();
            if (maxOrNull == null) {
                return;
            }
            randMax = maxOrNull as Double;
            rollRandom();
            exitEmbeddedFlow(engine.expr);
            switchScreen(SCREEN_BASIC);
            return;
        } else if (action.equals("randBack")) {
            switchScreen(SCREEN_MENU);
            return;
        } else if (action.equals("tip")) {
            enterEmbeddedFlow();
            tipStage = 0;
            switchScreen(SCREEN_TIP);
            return;
        } else if (action.equals("tipNext")) {
            var entryOrNull = readEntry();
            if (entryOrNull == null) {
                return;
            }
            if (tipStage == 0) {
                tipBill = entryOrNull as Double;
            } else {
                tipPct = entryOrNull as Double;
            }
            engine.clear();
            goToTipStage(tipStage + 1);
            return;
        } else if (action.equals("tipGo")) {
            var pplOrNull = readEntry();
            if (pplOrNull == null) {
                return;
            }
            var ppl = (Math.round(pplOrNull as Double) as Numeric).toNumber();
            if (ppl < 1) {
                ppl = 1;
            }
            var total = tipBill * (1.0d + tipPct / 100.0d);
            engine.setResult(total / ppl);
            exitEmbeddedFlow(engine.expr);
            switchScreen(SCREEN_BASIC);
            return;
        } else if (action.equals("tipBack")) {
            switchScreen(SCREEN_MENU);
            return;
        }

        var idxOrNull = action.find(":");
        if (idxOrNull == null) {
            return;
        }
        var idx = idxOrNull as Number;
        var prefix = action.substring(0, idx) as String;
        var value = action.substring(idx + 1, action.length()) as String;
        if (prefix.equals("digit")) {
            engine.appendDigit(value);
        } else if (prefix.equals("op")) {
            engine.appendOperator(value);
        } else if (prefix.equals("func")) {
            engine.appendFunction(value);
        } else if (prefix.equals("const")) {
            engine.appendConstant(value);
        } else if (prefix.equals("cat")) {
            unitCategory = value;
            switchScreen(SCREEN_UNIT_PICK);
            if (value.equals("cur")) {
                refreshCurrencyRates();
            }
        } else if (prefix.equals("unit")) {
            if (handleUnitTap(value)) {
                exitEmbeddedFlow(engine.expr);
                switchScreen(SCREEN_BASIC);
            } else if (screen != SCREEN_UNIT_PICK) {
                goToScreen(SCREEN_UNIT_PICK);
            }
        } else if (prefix.equals("curletter")) {
            curMatches = currencyCodesStartingWith(value);
            if (curMatches.size() == 1) {
                if (handleUnitTap(curMatches[0])) {
                    exitEmbeddedFlow(engine.expr);
                    switchScreen(SCREEN_BASIC);
                } else {
                    goToScreen(SCREEN_UNIT_PICK);
                }
            } else if (curMatches.size() == 0) {
                goToScreen(SCREEN_UNIT_PICK);
            } else {
                goToScreen(SCREEN_CUR_RESULTS);
            }
        } else if (prefix.equals("sto")) {
            engine.storeVar(value);
        } else if (prefix.equals("rcl")) {
            engine.recallVar(value);
        }
    }

    // First tap on the unit-pick screen records the source unit (and is
    // highlighted in onUpdate); the second tap on a *different* unit
    // evaluates the engine's current expression and converts it. Tapping
    // the same unit again cancels the selection. Returns true once a
    // conversion has actually been computed (the caller then exits the
    // embedded flow and splices the result back into the real expression).
    private function handleUnitTap(key as String) as Boolean {
        if (fromUnitKey == null) {
            fromUnitKey = key;
            return false;
        }
        var from = fromUnitKey as String;
        fromUnitKey = null;
        if (from.equals(key)) {
            return false;
        }
        var valOrNull = engine.evaluateToDouble();
        if (valOrNull == null) {
            return false;
        }
        var result = convertValue(unitCategory, from, key, valOrNull as Double);
        if (key.equals("/km") || key.equals("/mi")) {
            // Runners read pace as m:ss; ExprParser reads "m:ss" back, so the
            // result can still be converted again.
            engine.setResultText(formatPace(result));
        } else {
            engine.setResult(result);
        }
        return true;
    }

    private function formatPace(minutes as Double) as String {
        var total = (Math.round(minutes * 60.0d) as Numeric).toNumber();
        var secs = total % 60;
        return (total / 60).toString() + ":" + (secs < 10 ? "0" : "") + secs.toString();
    }

    // Reads whatever's been typed on the random screen as a number. An
    // untouched keypad (nothing typed yet) counts as 0 rather than an
    // error, so pressing NEXT/GEN without typing anything just rolls with
    // that bound as 0 instead of silently doing nothing.
    private function readEntry() as Double? {
        if (engine.expr.length() == 0 && !engine.errorState) {
            return 0.0d;
        }
        return engine.evaluateToDouble();
    }

    private function goToRandomStage(stage as Number) as Void {
        randStage = stage;
        selectedIndex = 0;
        layoutButtons();
    }

    private function goToTipStage(stage as Number) as Void {
        tipStage = stage;
        selectedIndex = 0;
        layoutButtons();
    }

    // Rolls a random whole number in [min, max] (bounds are rounded and
    // swapped if entered backwards) and shows it via the engine's display.
    private function rollRandom() as Void {
        var lo = (Math.round(randMin) as Numeric).toNumber();
        var hi = (Math.round(randMax) as Numeric).toNumber();
        if (hi < lo) {
            var tmp = lo;
            lo = hi;
            hi = tmp;
        }
        var range = hi - lo + 1;
        var r = Math.rand() % range;
        if (r < 0) {
            r = r + range;
        }
        engine.setResult((lo + r).toDouble());
    }

    private function convertValue(category as String, from as String, to as String, v as Double) as Double {
        if (category.equals("temp")) {
            return convertTemp(from, to, v);
        }
        if (category.equals("pace")) {
            return convertPace(from, to, v);
        }
        if (category.equals("cur")) {
            var rf = currencyRates[from];
            var rt = currencyRates[to];
            if (rf == null || rt == null) {
                return v;
            }
            return v / (rf as Double) * (rt as Double);
        }
        var ffrom = unitFactor(category, from);
        var fto = unitFactor(category, to);
        if (ffrom == null || fto == null) {
            return v;
        }
        // Every non-temperature unit's factor converts it to a common base
        // unit (meters / kg / kph / liters), so from->to is a single ratio.
        return v * (ffrom as Double) / (fto as Double);
    }

    // Via Celsius, so every pair of c/f/K works.
    private function convertTemp(from as String, to as String, v as Double) as Double {
        var c = v;
        if (from.equals("f")) {
            c = (v - 32.0d) * 5.0d / 9.0d;
        } else if (from.equals("K")) {
            c = v - 273.15d;
        }
        if (to.equals("f")) {
            return c * 9.0d / 5.0d + 32.0d;
        } else if (to.equals("K")) {
            return c + 273.15d;
        }
        return c;
    }

    // Pace (minutes per km / mile) is the reciprocal of speed, so it can't
    // use the single-ratio path; everything goes through kph. A zero pace or
    // speed maps to 0 rather than dividing by zero.
    private function convertPace(from as String, to as String, v as Double) as Double {
        var kph = v;
        if (from.equals("/km") || from.equals("/mi")) {
            if (v == 0.0d) {
                return 0.0d;
            }
            kph = 60.0d / v * (from.equals("/mi") ? 1.60934d : 1.0d);
        } else if (from.equals("mph")) {
            kph = v * 1.60934d;
        }
        if (to.equals("/km") || to.equals("/mi")) {
            if (kph == 0.0d) {
                return 0.0d;
            }
            return 60.0d / kph * (to.equals("/mi") ? 1.60934d : 1.0d);
        } else if (to.equals("mph")) {
            return kph / 1.60934d;
        }
        return kph;
    }

    private function unitFactor(category as String, key as String) as Double? {
        if (category.equals("dist")) {
            if (key.equals("km")) { return 1000.0d; }
            else if (key.equals("mi")) { return 1609.34d; }
            else if (key.equals("m")) { return 1.0d; }
            else if (key.equals("ft")) { return 0.3048d; }
            else if (key.equals("cm")) { return 0.01d; }
            else if (key.equals("in")) { return 0.0254d; }
            else if (key.equals("yd")) { return 0.9144d; }
            else if (key.equals("NM")) { return 1852.0d; }
        } else if (category.equals("weight")) {
            if (key.equals("kg")) { return 1.0d; }
            else if (key.equals("g")) { return 0.001d; }
            else if (key.equals("lb")) { return 0.453592d; }
            else if (key.equals("oz")) { return 0.0283495d; }
            else if (key.equals("st")) { return 6.35029d; }
        } else if (category.equals("speed")) {
            if (key.equals("kph")) { return 1.0d; }
            else if (key.equals("mph")) { return 1.60934d; }
            else if (key.equals("m/s")) { return 3.6d; }
            else if (key.equals("kn")) { return 1.852d; }
        } else if (category.equals("vol")) {
            if (key.equals("l")) { return 1.0d; }
            else if (key.equals("mL")) { return 0.001d; }
            else if (key.equals("gal")) { return 3.78541d; }
            else if (key.equals("cup")) { return 0.236588d; }
            else if (key.equals("floz")) { return 0.0295735d; }
        } else if (category.equals("area")) {
            if (key.equals("m2")) { return 1.0d; }
            else if (key.equals("km2")) { return 1000000.0d; }
            else if (key.equals("ha")) { return 10000.0d; }
            else if (key.equals("acre")) { return 4046.86d; }
            else if (key.equals("ft2")) { return 0.092903d; }
            else if (key.equals("mi2")) { return 2589988.0d; }
        } else if (category.equals("time")) {
            if (key.equals("sec")) { return 1.0d; }
            else if (key.equals("min")) { return 60.0d; }
            else if (key.equals("hr")) { return 3600.0d; }
            else if (key.equals("day")) { return 86400.0d; }
            else if (key.equals("wk")) { return 604800.0d; }
        } else if (category.equals("pres")) {
            if (key.equals("bar")) { return 100000.0d; }
            else if (key.equals("kPa")) { return 1000.0d; }
            else if (key.equals("hPa")) { return 100.0d; }
            else if (key.equals("psi")) { return 6894.76d; }
            else if (key.equals("atm")) { return 101325.0d; }
            else if (key.equals("mmHg")) { return 133.322d; }
        } else if (category.equals("energy")) {
            if (key.equals("kcal")) { return 4184.0d; }
            else if (key.equals("kJ")) { return 1000.0d; }
            else if (key.equals("kWh")) { return 3600000.0d; }
        }
        return null;
    }

    // Modern flat-color-by-category palette (custom hex, not the stock
    // 16-color Graphics.COLOR_* set) so a glance at a button's color tells
    // you what kind of thing it does: digits are neutral, math operators
    // amber, destructive actions coral, "=" green, navigation/menu purple,
    // scientific functions teal, everything else utility blue.
    private const ACCENT_DIGIT = 0x23233A;
    private const ACCENT_OP = 0xFFB020;
    private const ACCENT_EQUALS = 0x00D68F;
    private const ACCENT_DESTRUCTIVE = 0xFF5470;
    private const ACCENT_NAV = 0x7C4DFF;
    private const ACCENT_FUNC = 0x00BBD3;
    private const ACCENT_UTILITY = 0x4C6FFF;
    private const ACCENT_SELECT_RING = 0x00E5FF;
    private const ACCENT_FROM_UNIT = 0xFFD166;
    private const BG_TOP = 0x14141F;

    private function buttonColor(action as String) as Number {
        if (action.equals("equals") || action.equals("eq")) {
            return ACCENT_EQUALS;
        } else if (action.equals("clear") || action.equals("back") || action.equals("varClear")) {
            return ACCENT_DESTRUCTIVE;
        } else if (action.equals("menu") || action.find("Back") != null || action.equals("basic")) {
            return ACCENT_NAV;
        } else if (action.find("digit:") == 0) {
            return ACCENT_DIGIT;
        } else if (action.find("op:") == 0) {
            return ACCENT_OP;
        } else if (action.find("func:") == 0 || action.find("const:") == 0 || action.equals("sqr") ||
            action.equals("open") || action.equals("close")) {
            return ACCENT_FUNC;
        } else {
            return ACCENT_UTILITY;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var headerHBg = (safeH * 0.24).toNumber();
        dc.setColor(BG_TOP, BG_TOP);
        dc.fillRectangle(safeX, safeY, safeW, headerHBg);

        dc.setColor(Graphics.COLOR_WHITE, BG_TOP);
        var text = engine.displayText();
        // While picking the unit converter's target unit, show what's been
        // picked so far instead of the raw expression, so the two-tap flow
        // ("source unit, then target unit") is self-explanatory.
        if ((screen == SCREEN_UNIT_PICK || screen == SCREEN_CUR_LETTER || screen == SCREEN_CUR_RESULTS) && fromUnitKey != null) {
            text = "FROM " + unitLabel(fromUnitKey as String) + "...";
        } else if (screen == SCREEN_RANDOM) {
            if (randStage == 0) {
                text = "MIN? " + text;
            } else {
                text = "MIN " + formatWhole(randMin) + " MAX? " + text;
            }
        } else if (screen == SCREEN_TIP) {
            if (tipStage == 0) {
                text = "BILL? " + text;
            } else if (tipStage == 1) {
                text = "TIP%? " + text;
            } else {
                text = "PPL? " + text;
            }
        }
        // Regular text fonts, not FONT_NUMBER_*: the expression can contain
        // letters and symbols (X, =, sin, etc.), and the digit-only number
        // fonts have no glyphs for those.
        var font = text.length() > 10 ? Graphics.FONT_TINY : (text.length() > 6 ? Graphics.FONT_SMALL : Graphics.FONT_LARGE);
        var headerH = (safeH * 0.24).toNumber();
        dc.drawText(safeX + safeW / 2, safeY + headerH / 2, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var setVars = "";
        var varNames = ["A", "B", "C", "D"];
        for (var vi = 0; vi < varNames.size(); vi++) {
            if (engine.variables.hasKey(varNames[vi])) {
                setVars += varNames[vi];
            }
        }
        if (setVars.length() > 0) {
            dc.drawText(safeX, safeY, Graphics.FONT_XTINY, setVars, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Small-cell screens (long labels like "asin"/"floor" packed 4x6, or
        // narrow 2-col pickers) need FONT_TINY - FONT_SMALL overflows the
        // cell and bleeds into neighboring buttons.
        var isSmallCellScreen = screen == SCREEN_UNITS || screen == SCREEN_UNIT_PICK || screen == SCREEN_CUR_LETTER ||
            screen == SCREEN_CUR_RESULTS || screen == SCREEN_VAR || screen == SCREEN_ADVANCED || screen == SCREEN_SCIENTIFIC;
        var buttonFont = screen == SCREEN_BASIC ? Graphics.FONT_MEDIUM : (isSmallCellScreen ? Graphics.FONT_TINY : Graphics.FONT_SMALL);
        for (var i = 0; i < buttons.size(); i++) {
            var b = buttons[i];
            var minDim = b.w < b.h ? b.w : b.h;
            var radius = (minDim / 6).toNumber();
            if (radius < 4) {
                radius = 4;
            }
            // A radius past half the shorter side makes the corner arcs
            // overlap and pinch a notch into the middle of the edge - cap it.
            var maxRadius = ((minDim - 6) / 2).toNumber();
            if (radius > maxRadius) {
                radius = maxRadius;
            }
            if (radius < 0) {
                radius = 0;
            }
            var isSelected = i == selectedIndex;
            var isFromUnit = screen == SCREEN_UNIT_PICK && fromUnitKey != null && b.action.equals("unit:" + (fromUnitKey as String));
            var fill = isFromUnit ? ACCENT_FROM_UNIT : buttonColor(b.action);

            // Selection is a ring drawn AS A SECOND, SLIGHTLY LARGER FILL
            // underneath the button's own fill (not a stroked outline on
            // top) - drawRoundedRectangle's stroke overlapped the fill's own
            // corner arcs and left a black notch cut into the edge.
            if (isSelected) {
                dc.setColor(ACCENT_SELECT_RING, ACCENT_SELECT_RING);
                dc.fillRoundedRectangle(b.x + 1, b.y + 1, b.w - 2, b.h - 2, radius);
            }
            dc.setColor(fill, fill);
            dc.fillRoundedRectangle(b.x + 3, b.y + 3, b.w - 6, b.h - 6, radius);

            var icon = b.icon;
            var labelColor = (fill == ACCENT_FROM_UNIT || fill == ACCENT_OP) ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
            if (icon != null) {
                dc.drawBitmap(b.x + (b.w - icon.getWidth()) / 2, b.y + (b.h - icon.getHeight()) / 2, icon);
            } else {
                // Every other basic-screen button is a single character;
                // "MENU" is the one long label there and needs its own
                // smaller font so it doesn't overflow its cell.
                var labelFont = (screen == SCREEN_BASIC && b.label.equals("MENU")) ? Graphics.FONT_XTINY : buttonFont;
                dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(b.x + b.w / 2, b.y + b.h / 2, labelFont, b.label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    function onHide() as Void {
    }

}

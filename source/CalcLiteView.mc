import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Calculator for the handful of devices too memory-constrained to run the
// full calc_for_garminView at all (see the pool comment at the top of
// SeedConfig.mc for that device list, and project memory for background).
// Same class name as the full view - `(:exclude_oldwidget)`/
// `(:oldwidget_only)` picks exactly one of the two per device (see
// monkey.jungle), so calc-for-garminApp.mc, calc-for-garminDelegate.mc and
// CalcLaunchView/CalcLaunchDelegate need no changes at all. Screen ids
// match the full view's numbering exactly where both implement the same
// screen, so calc-for-garminDelegate.mc's shared BACK_TARGET table (written
// for the full view) still sends BACK to the right place here too.
//
// Everything reachable from MENU/MORE is here (Scientific, Advanced,
// Units + currency conversion, Random, Tip, advanced %, Date, Var, Nav)
// except GRAPH/BASE/COLOR/COUNTER/FORMULAS/HISTORY/the QR setup page - a
// pasted SEED can still place any of those tokens, they're just inert
// here. Currency uses the same fixed starter rates the full app falls
// back to with no internet - no live rate fetch here, to keep this build
// small; still real conversion between real currencies, just not
// refreshed.
(:oldwidget_only)
class calc_for_garminView extends WatchUi.View {

    const SCREEN_BASIC = 0;
    const SCREEN_SCIENTIFIC = 1;
    const SCREEN_ADVANCED = 2;
    const SCREEN_UNITS = 3;
    const SCREEN_UNIT_PICK = 4;
    const SCREEN_CUR_LETTER = 5;
    const SCREEN_CUR_RESULTS = 6;
    const SCREEN_RANDOM = 7;
    const SCREEN_TIP = 8;
    const SCREEN_VAR = 9;
    const SCREEN_MENU = 10;
    const SCREEN_PCT = 12;
    const SCREEN_DATE = 13;
    const SCREEN_MORE = 14;
    const SCREEN_NAV = 15;
    // Not real screens here - only exist so calc-for-garminDelegate.mc's
    // shared goBack()/onSwipe() logic (written for the full view's 26
    // screens) still compiles. `screen` never actually becomes one of
    // these, so the branches that check for them never fire.
    const SCREEN_BASE = 93;
    const SCREEN_COUNTER = 94;
    const SCREEN_HISTORY = 95;

    const CURRENCY_KEYS = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"] as Array<String>;
    const DEFAULT_CURRENCY_RATES = {
        "USD" => 1.0d, "EUR" => 0.92d, "GBP" => 0.79d, "JPY" => 149.5d, "CAD" => 1.36d, "AUD" => 1.52d,
    } as Dictionary<String, Double>;
    private var currencyRates as Dictionary<String, Double> = DEFAULT_CURRENCY_RATES;
    private var unitCategory as String = "";
    private var fromUnitKey as String? = null;
    private var curMatches as Array<String> = [] as Array<String>;

    private const VAR_LETTERS = "ABCDFGHIJKLMNOPQRSTUVWXYZ";

    var engine as CalculatorEngine = new CalculatorEngine();
    var screen as Number = SCREEN_BASIC;
    var selectedIndex as Number = 0;
    private var buttons as Array<CalcButton> = [] as Array<CalcButton>;

    // Stashes the expression being built so a temporary value (random/tip/
    // %/date result) can be typed on another screen without losing it -
    // same trick as the full view's enterEmbeddedFlow()/exitEmbeddedFlow().
    private var pendingExpr as String? = null;
    private var pendingCursor as Number = 0;

    private var randStage as Number = 0;
    private var randMin as Double = 0.0d;
    private var randMax as Double = 0.0d;

    private var tipStage as Number = 0;
    private var tipBill as Double = 0.0d;
    private var tipPct as Double = 0.0d;

    private var pctStage as Number = 0;
    private var pctMode as Number = 0;
    private var pctBase as Double = 0.0d;

    private var dateStage as Number = 0;
    private var dateMode as Number = 0;
    private var dateYear as Number = 0;
    private var dateMonth as Number = 0;
    private var dateDay as Number = 0;
    private var dateYear2 as Number = 0;
    private var dateMonth2 as Number = 0;
    private var dateDay2 as Number = 0;

    private var ACCENT_DIGIT = 0x23233A;
    private var ACCENT_OP = 0xFFB020;
    private var ACCENT_EQUALS = 0x00D68F;
    private var ACCENT_DESTRUCTIVE = 0xFF5470;
    private var ACCENT_NAV = 0x7C4DFF;
    private var BG_TOP = 0x14141F;
    private const ACCENT_FUNC = 0x00BBD3;
    private const ACCENT_UTILITY = 0x4C6FFF;
    private const ACCENT_SELECT_RING = 0x00E5FF;

    private var safeX as Number = 0;
    private var safeY as Number = 0;
    private var safeW as Number = 0;
    private var safeH as Number = 0;

    function initialize() {
        View.initialize();
        refreshTheme();
    }

    function refreshTheme() as Void {
        var colors = SeedConfig.get().colors;
        ACCENT_DIGIT = colors[0];
        ACCENT_OP = colors[1];
        ACCENT_EQUALS = colors[2];
        ACCENT_DESTRUCTIVE = colors[3];
        ACCENT_NAV = colors[4];
        BG_TOP = colors[5];
    }

    function refreshLayout() as Void {
        layoutButtons();
    }

    function onLayout(dc as Dc) as Void {
        var isRound = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (isRound) {
            var side = (w < h ? w : h) * 0.72;
            safeW = side.toNumber();
            safeH = safeW;
            safeX = (w - safeW) / 2;
            safeY = (h - safeH) / 2;
        } else {
            safeX = 0;
            safeY = 0;
            safeW = w;
            safeH = h;
        }
        layoutButtons();
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    function getButtons() as Array<CalcButton> {
        return buttons;
    }

    function buttonAt(x as Number, y as Number) as Number? {
        for (var i = 0; i < buttons.size(); i++) {
            if (buttons[i].contains(x, y)) {
                return i;
            }
        }
        return null;
    }

    function isListScreen() as Boolean {
        return false;
    }

    function scrollList(delta as Number) as Void {
    }

    function moveSelection(delta as Number) as Void {
        if (buttons.size() == 0) {
            return;
        }
        selectedIndex = (selectedIndex + delta + buttons.size()) % buttons.size();
    }

    private function enterEmbeddedFlow() as Void {
        var expr = engine.expr;
        if (endsMidExpression(expr)) {
            pendingExpr = expr;
            pendingCursor = engine.cursorPos;
            engine.clear();
        } else {
            pendingExpr = "";
            pendingCursor = 0;
        }
    }

    private function endsMidExpression(expr as String) as Boolean {
        if (expr.length() == 0) {
            return true;
        }
        if (expr.length() >= 3 && expr.substring(expr.length() - 3, expr.length()).equals("mod")) {
            return true;
        }
        var last = expr.substring(expr.length() - 1, expr.length());
        return last.equals("+") || last.equals("-") || last.equals("*") || last.equals("/") ||
            last.equals("^") || last.equals("(");
    }

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

    // Anything that isn't one of the screens implemented here (e.g. the
    // delegate's BACK_TARGET table sending a screen "back" to a real-app
    // screen this build doesn't have) falls back to Basic - the nearest
    // sensible "home" - rather than being ignored, so BACK/ESC always goes
    // somewhere instead of doing nothing.
    private function knownScreen(s as Number) as Boolean {
        return s == SCREEN_BASIC || s == SCREEN_SCIENTIFIC || s == SCREEN_ADVANCED ||
            s == SCREEN_UNITS || s == SCREEN_UNIT_PICK || s == SCREEN_CUR_LETTER || s == SCREEN_CUR_RESULTS ||
            s == SCREEN_RANDOM || s == SCREEN_TIP || s == SCREEN_VAR || s == SCREEN_MENU ||
            s == SCREEN_PCT || s == SCREEN_DATE || s == SCREEN_MORE || s == SCREEN_NAV;
    }

    function switchScreen(newScreen as Number) as Void {
        if (pendingExpr != null && (newScreen == SCREEN_BASIC || newScreen == SCREEN_SCIENTIFIC || newScreen == SCREEN_ADVANCED)) {
            exitEmbeddedFlow(null);
        }
        fromUnitKey = null;
        goToScreen(newScreen);
    }

    function goToScreen(newScreen as Number) as Void {
        screen = knownScreen(newScreen) ? newScreen : SCREEN_BASIC;
        selectedIndex = 0;
        layoutButtons();
    }

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

    private function goToPctStage(stage as Number) as Void {
        pctStage = stage;
        selectedIndex = 0;
        layoutButtons();
    }

    private function goToDateStage(stage as Number) as Void {
        dateStage = stage;
        selectedIndex = 0;
        layoutButtons();
    }

    private function randomExpr() as String {
        var lo = (Math.round(randMin) as Numeric).toNumber();
        var hi = (Math.round(randMax) as Numeric).toNumber();
        if (hi < lo) {
            var tmp = lo;
            lo = hi;
            hi = tmp;
        }
        return lo.toString() + "+rand(" + (hi - lo).toString() + ")";
    }

    private function pctExpr(mode as Number, base as Double, pct as Double) as String {
        var baseStr = engine.formatNumber(base);
        var pctStr = engine.formatNumber(pct);
        if (mode == 0) {
            return baseStr + "*(1-" + pctStr + "/100)";
        } else if (mode == 1) {
            return baseStr + "*(1+" + pctStr + "/100)";
        }
        return baseStr + "/(1-" + pctStr + "/100)";
    }

    private function clampRange(v as Number, lo as Number, hi as Number) as Number {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

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
        return v * (ffrom as Double) / (fto as Double);
    }

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
        var f = specLookup(",dist.km~1000,dist.mi~1609.34,dist.m~1,dist.ft~0.3048,dist.cm~0.01,dist.in~0.0254,dist.yd~0.9144,dist.NM~1852,weight.kg~1,weight.g~0.001,weight.lb~0.453592,weight.oz~0.0283495,weight.st~6.35029,speed.kph~1,speed.mph~1.60934,speed.m/s~3.6,speed.kn~1.852,vol.l~1,vol.mL~0.001,vol.gal~3.78541,vol.cup~0.236588,vol.floz~0.0295735,area.m2~1,area.km2~1000000,area.ha~10000,area.acre~4046.86,area.ft2~0.092903,area.mi2~2589988,time.sec~1,time.min~60,time.hr~3600,time.day~86400,time.wk~604800,pres.bar~100000,pres.kPa~1000,pres.hPa~100,pres.psi~6894.76,pres.atm~101325,pres.mmHg~133.322,energy.kcal~4184,energy.kJ~1000,energy.kWh~3600000,", category + "." + key);
        return f != null ? f[0].toDouble() : null;
    }

    private function daysUntil(year as Number, month as Number, day as Number) as Number {
        var target = Gregorian.moment({
            :year => year, :month => clampRange(month, 1, 12), :day => clampRange(day, 1, 31),
            :hour => 0, :minute => 0, :second => 0
        });
        var diffSeconds = target.value() - Time.now().value();
        return (diffSeconds / 86400.0d).toNumber();
    }

    private function ageInYears(year as Number, month as Number, day as Number) as Number {
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var m = clampRange(month, 1, 12);
        var d = clampRange(day, 1, 31);
        var age = today.year - year;
        if (today.month < m || (today.month == m && today.day < d)) {
            age -= 1;
        }
        return age < 0 ? 0 : age;
    }

    private function daysBetween(y1 as Number, m1 as Number, d1 as Number, y2 as Number, m2 as Number, d2 as Number) as Number {
        var a = Gregorian.moment({
            :year => y1, :month => clampRange(m1, 1, 12), :day => clampRange(d1, 1, 31),
            :hour => 0, :minute => 0, :second => 0
        });
        var b = Gregorian.moment({
            :year => y2, :month => clampRange(m2, 1, 12), :day => clampRange(d2, 1, 31),
            :hour => 0, :minute => 0, :second => 0
        });
        var diff = ((b.value() - a.value()) / 86400.0d).toNumber();
        return diff < 0 ? -diff : diff;
    }

    // "label~action,label~action" -> buttons, for fixed button sets.
    private function btns(spec as String) as Array<CalcButton> {
        var parts = splitStr(spec, ",");
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < parts.size(); i++) {
            var f = splitStr(parts[i], "~");
            defs.add(new CalcButton(f[0], f[1]));
        }
        return defs;
    }

    private function keypadButtons(backAction as String, nextLabel as String, nextAction as String) as Array<CalcButton> {
        var defs = btns("7~digit:7,8~digit:8,9~digit:9,DEL~back,4~digit:4,5~digit:5,6~digit:6,C~clear,1~digit:1,2~digit:2,3~digit:3,-~op:-,0~digit:0,.~digit:.");
        defs.add(new CalcButton("BACK", backAction));
        defs.add(new CalcButton(nextLabel, nextAction));
        return defs;
    }

    private function basicButtons() as Array<CalcButton> {
        return buttonsFromTokens(SeedConfig.get().basicLayout());
    }

    private function scientificButtons() as Array<CalcButton> {
        return buttonsFromTokens(SeedConfig.get().sciLayout());
    }

    private function advancedButtons() as Array<CalcButton> {
        return buttonsFromTokens(SeedConfig.get().advLayout());
    }

    private function unitCategoryButtons() as Array<CalcButton> {
        return buttonsFromTokens(SeedConfig.get().unitsLayout());
    }

    private function unitKeysFor(category as String) as Array<String> {
        if (category.equals("cur")) {
            return CURRENCY_KEYS;
        }
        var keys = specLookup(",dist~km~mi~m~ft~cm~in~yd~NM,weight~kg~g~lb~oz~st,temp~c~f~K,speed~kph~mph~m/s~kn,pace~/km~/mi~kph~mph,vol~l~mL~gal~cup~floz,area~m2~km2~ha~acre~ft2~mi2,time~sec~min~hr~day~wk,pres~bar~kPa~hPa~psi~atm~mmHg,energy~kcal~kJ~kWh,", category);
        return keys != null ? keys : [] as Array<String>;
    }

    private function unitLabel(key as String) as String {
        var f = specLookup(",c~°C,f~°F,l~L,", key);
        return f != null ? f[0] : key;
    }

    private function unitPickButtons() as Array<CalcButton> {
        var keys = unitKeysFor(unitCategory);
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < keys.size(); i++) {
            defs.add(new CalcButton(unitLabel(keys[i]), "unit:" + keys[i]));
        }
        if (unitCategory.equals("cur")) {
            defs.add(new CalcButton("OTHER", "curOther"));
        }
        defs.add(new CalcButton("C", "clear"));
        defs.add(new CalcButton("BACK", "unitCatBack"));
        return defs;
    }

    // Array.sort() is CIQ 3.4.0+; some of these devices cap lower - same
    // insertion sort the full view uses.
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

    private function varButtons() as Array<CalcButton> {
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < VAR_LETTERS.length(); i++) {
            var letter = VAR_LETTERS.substring(i, i + 1) as String;
            defs.add(new CalcButton(letter, "const:" + letter));
        }
        defs.addAll(btns("=~eq,CLR~varClear,BACK~menu"));
        return defs;
    }

    private function randomButtons() as Array<CalcButton> {
        return keypadButtons("randBack", randStage == 0 ? "NEXT" : "GEN", randStage == 0 ? "randNext" : "randGen");
    }

    private function tipButtons() as Array<CalcButton> {
        return keypadButtons("tipBack", tipStage == 2 ? "GO" : "NEXT", tipStage == 2 ? "tipGo" : "tipNext");
    }

    private function pctButtons() as Array<CalcButton> {
        if (pctStage == 0) {
            return btns("DISCOUNT~pctMode:0,MARKUP~pctMode:1,MARGIN~pctMode:2,BACK~pctBack");
        }
        return keypadButtons("pctBack", pctStage == 2 ? "GO" : "NEXT", pctStage == 2 ? "pctGo" : "pctNext");
    }

    private function dateButtons() as Array<CalcButton> {
        if (dateStage == 0) {
            return btns("UNTIL~dateMode:0,AGE~dateMode:1,DIFF~dateMode:2,BACK~dateBack");
        }
        var lastStage = dateMode == 2 ? 6 : 3;
        return keypadButtons("dateBack", dateStage == lastStage ? "GO" : "NEXT", dateStage == lastStage ? "dateGo" : "dateNext");
    }

    private function moreButtons() as Array<CalcButton> {
        return btns("PCT+~apct,DATE~date,VAR~var,BACK~moreBack");
    }

    private function menuButtons() as Array<CalcButton> {
        var items = SeedConfig.get().menuItems();
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < items.size(); i++) {
            var f = specLookup(",sci~fx~sci,units~Units~units,tip~Tip~tip,rnd~RND~random,var~VAR~var,apct~PCT+~apct,date~DATE~date,nav~NAV~nav,", items[i]);
            if (f != null) {
                defs.add(new CalcButton(f[0], f[1]));
            }
        }
        defs.add(new CalcButton("BACK", "basic"));
        return defs;
    }

    private function navButtons() as Array<CalcButton> {
        return btns("<~curLeft,>~curRight,Ans~ans,(~open,)~close,a/b~frac,BACK~menu");
    }

    private function tokenToButton(token as String) as CalcButton {
        var f = specLookup(MODULE_TOKEN_SPEC, token);
        if (f == null) {
            return new CalcButton(token, "digit:" + token);
        }
        return new CalcButton(f[0], f[1]);
    }

    private function buttonsFromTokens(tokens as Array<String>) as Array<CalcButton> {
        var defs = [] as Array<CalcButton>;
        for (var i = 0; i < tokens.size(); i++) {
            defs.add(tokenToButton(tokens[i]));
        }
        return defs;
    }

    private function layoutButtons() as Void {
        var defs = [] as Array<CalcButton>;
        var cols = 4;
        if (screen == SCREEN_SCIENTIFIC) {
            defs = scientificButtons();
        } else if (screen == SCREEN_ADVANCED) {
            defs = advancedButtons();
        } else if (screen == SCREEN_UNITS) {
            defs = unitCategoryButtons();
            cols = 3;
        } else if (screen == SCREEN_UNIT_PICK) {
            defs = unitPickButtons();
            cols = defs.size() > 8 ? 3 : 2;
        } else if (screen == SCREEN_CUR_LETTER) {
            defs = curLetterButtons();
            cols = 5;
        } else if (screen == SCREEN_CUR_RESULTS) {
            defs = curResultButtons();
            cols = 2;
        } else if (screen == SCREEN_RANDOM) {
            defs = randomButtons();
        } else if (screen == SCREEN_TIP) {
            defs = tipButtons();
        } else if (screen == SCREEN_PCT) {
            defs = pctButtons();
            cols = pctStage == 0 ? 2 : 4;
        } else if (screen == SCREEN_DATE) {
            defs = dateButtons();
            cols = dateStage == 0 ? 2 : 4;
        } else if (screen == SCREEN_MORE) {
            defs = moreButtons();
            cols = 2;
        } else if (screen == SCREEN_NAV) {
            defs = navButtons();
            cols = 3;
        } else if (screen == SCREEN_VAR) {
            defs = varButtons();
            cols = 5;
        } else if (screen == SCREEN_MENU) {
            defs = menuButtons();
            cols = 2;
        } else {
            defs = basicButtons();
        }
        var rows = (defs.size() + cols - 1) / cols;
        var headerH = (safeH * 0.24).toNumber();
        var gridTop = safeY + headerH;
        var gridH = safeH - headerH;
        var cellW = safeW / cols;
        var cellH = gridH / rows;
        var others = [] as Array<CalcButton>;
        // BACK is a normal pool token on basic/sci/adv (can be moved), but
        // pinned to the bottom-right corner everywhere else, same rule as
        // the full view.
        var customizableScreen = screen == SCREEN_BASIC || screen == SCREEN_SCIENTIFIC || screen == SCREEN_ADVANCED || screen == SCREEN_UNITS;
        var backBtn = null as CalcButton?;
        if (customizableScreen) {
            others = defs;
        } else {
            for (var oi = 0; oi < defs.size(); oi++) {
                if (backBtn == null && defs[oi].label.equals("BACK")) {
                    backBtn = defs[oi];
                } else {
                    others.add(defs[oi]);
                }
            }
        }
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
        if (screen == SCREEN_SCIENTIFIC) {
            var moreSize = (headerH * 0.5).toNumber();
            var moreBtn = new CalcButton("MORE", "more");
            moreBtn.x = safeX + safeW - moreSize - 4;
            moreBtn.y = safeY + 4;
            moreBtn.w = moreSize;
            moreBtn.h = moreSize;
            others.add(moreBtn);
        }
        buttons = others;
    }

    // "menu"/"backSci" toggle Basic<->Scientific and MENU takes over as the
    // real hub once reached - see menuButtons()/moreButtons(). Anything the
    // full app would send to a screen that doesn't exist on this build
    // (units, history, ...) is simply ignored - the button still shows (a
    // pasted SEED can still place it), it just does nothing when tapped.
    function activate(b as CalcButton) as Void {
        var action = b.action;
        var target = specLookup(",sci~1,basic~0,menu~10,adv~2,var~9,nav~15,unitCatBack~3,randBack~10,tipBack~10,pctBack~14,dateBack~14,more~14,moreBack~1,backSci~1,", action);
        if (target != null) {
            switchScreen(target[0].toNumber() as Number);
            return;
        }
        if (action.equals("clear")) {
            engine.clear();
            fromUnitKey = null;
        } else if (action.equals("back")) {
            engine.backspace();
        } else if (action.equals("equals")) {
            engine.evaluate();
        } else if (action.equals("curLeft")) {
            engine.moveCursorLeft();
        } else if (action.equals("curRight")) {
            engine.moveCursorRight();
        } else if (action.equals("ans")) {
            engine.insertAns();
        } else if (action.equals("eq")) {
            engine.insertEquals();
        } else if (action.equals("varClear")) {
            engine.clearVariables();
        } else if (action.equals("open")) {
            engine.openParen();
        } else if (action.equals("close")) {
            engine.closeParen();
        } else if (action.equals("sqr")) {
            engine.wrapSquare();
        } else if (action.equals("cube")) {
            engine.wrapCube();
        } else if (action.equals("inv")) {
            engine.wrapInverse();
        } else if (action.equals("pow10")) {
            engine.wrapPow10();
        } else if (action.equals("frac")) {
            engine.toggleFraction();
        } else if (action.equals("fact")) {
            engine.wrapFactorial();
        } else if (action.equals("ee")) {
            engine.appendRaw("*10^");
        } else if (action.equals("units")) {
            enterEmbeddedFlow();
            switchScreen(SCREEN_UNITS);
        } else if (action.equals("curOther")) {
            goToScreen(SCREEN_CUR_LETTER);
        } else if (action.equals("curLetterBack")) {
            goToScreen(SCREEN_UNIT_PICK);
        } else if (action.equals("curResultsBack")) {
            goToScreen(SCREEN_CUR_LETTER);
        } else if (action.equals("random")) {
            enterEmbeddedFlow();
            randStage = 0;
            randMin = 0.0d;
            randMax = 0.0d;
            switchScreen(SCREEN_RANDOM);
        } else if (action.equals("randNext")) {
            var minOrNull = readEntry();
            if (minOrNull != null) {
                randMin = minOrNull as Double;
                engine.clear();
                goToRandomStage(1);
            }
        } else if (action.equals("randGen")) {
            var maxOrNull = readEntry();
            if (maxOrNull != null) {
                randMax = maxOrNull as Double;
                exitEmbeddedFlow(randomExpr());
                switchScreen(SCREEN_BASIC);
            }
        } else if (action.equals("tip")) {
            enterEmbeddedFlow();
            tipStage = 0;
            switchScreen(SCREEN_TIP);
        } else if (action.equals("tipNext")) {
            var entryOrNull = readEntry();
            if (entryOrNull != null) {
                if (tipStage == 0) {
                    tipBill = entryOrNull as Double;
                } else {
                    tipPct = entryOrNull as Double;
                }
                engine.clear();
                goToTipStage(tipStage + 1);
            }
        } else if (action.equals("tipGo")) {
            var pplOrNull = readEntry();
            if (pplOrNull != null) {
                var ppl = (Math.round(pplOrNull as Double) as Numeric).toNumber();
                if (ppl < 1) {
                    ppl = 1;
                }
                var tipExpr = "(" + engine.formatNumber(tipBill) + "*(1+" + engine.formatNumber(tipPct) + "/100))/" + ppl.toString();
                exitEmbeddedFlow(tipExpr);
                switchScreen(SCREEN_BASIC);
            }
        } else if (action.equals("apct")) {
            enterEmbeddedFlow();
            pctStage = 0;
            switchScreen(SCREEN_PCT);
        } else if (action.equals("pctNext")) {
            var entryOrNull = readEntry();
            if (entryOrNull != null) {
                pctBase = entryOrNull as Double;
                engine.clear();
                goToPctStage(2);
            }
        } else if (action.equals("pctGo")) {
            var pctOrNull = readEntry();
            if (pctOrNull != null) {
                exitEmbeddedFlow(pctExpr(pctMode, pctBase, pctOrNull as Double));
                switchScreen(SCREEN_BASIC);
            }
        } else if (action.equals("date")) {
            enterEmbeddedFlow();
            dateStage = 0;
            switchScreen(SCREEN_DATE);
        } else if (action.equals("dateNext")) {
            var entryOrNull = readEntry();
            if (entryOrNull != null) {
                var whole = (Math.round(entryOrNull as Double) as Numeric).toNumber();
                if (dateStage == 1) {
                    dateYear = whole;
                } else if (dateStage == 2) {
                    dateMonth = whole;
                } else if (dateStage == 3) {
                    dateDay = whole;
                } else if (dateStage == 4) {
                    dateYear2 = whole;
                } else {
                    dateMonth2 = whole;
                }
                engine.clear();
                goToDateStage(dateStage + 1);
            }
        } else if (action.equals("dateGo")) {
            var entryOrNull = readEntry();
            if (entryOrNull != null) {
                var whole = (Math.round(entryOrNull as Double) as Numeric).toNumber();
                if (dateMode == 0) {
                    dateDay = whole;
                    engine.setResult(daysUntil(dateYear, dateMonth, dateDay).toDouble());
                } else if (dateMode == 1) {
                    dateDay = whole;
                    engine.setResult(ageInYears(dateYear, dateMonth, dateDay).toDouble());
                } else {
                    dateDay2 = whole;
                    engine.setResult(daysBetween(dateYear, dateMonth, dateDay, dateYear2, dateMonth2, dateDay2).toDouble());
                }
                exitEmbeddedFlow(engine.expr);
                switchScreen(SCREEN_BASIC);
            }
        } else {
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
            } else if (prefix.equals("pctMode")) {
                pctMode = value.toNumber() as Number;
                engine.clear();
                goToPctStage(1);
            } else if (prefix.equals("dateMode")) {
                dateMode = value.toNumber() as Number;
                engine.clear();
                goToDateStage(1);
            } else if (prefix.equals("cat")) {
                unitCategory = value;
                switchScreen(SCREEN_UNIT_PICK);
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
            }
        }
    }

    private function buttonColor(action as String) as Number {
        if (action.equals("")) {
            return BG_TOP;
        } else if (action.equals("equals") || action.equals("eq")) {
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
            action.equals("open") || action.equals("close") || action.equals("frac")) {
            return ACCENT_FUNC;
        } else {
            return ACCENT_UTILITY;
        }
    }

    private function groupThousands(s as String) as String {
        var out = "";
        var i = 0;
        var n = s.length();
        while (i < n) {
            var c = s.substring(i, i + 1) as String;
            if ("0123456789".find(c) != null) {
                var j = i;
                while (j < n && "0123456789".find(s.substring(j, j + 1) as String) != null) {
                    j++;
                }
                var run = s.substring(i, j) as String;
                var prevChar = i > 0 ? (s.substring(i - 1, i) as String) : "";
                var skip = prevChar.equals(".") || prevChar.equals("e") || prevChar.equals("E");
                out += (!skip && run.length() > 3) ? insertCommas(run) : run;
                i = j;
            } else {
                out += c;
                i++;
            }
        }
        return out;
    }

    private function insertCommas(digits as String) as String {
        var n = digits.length();
        var firstGroup = n % 3;
        if (firstGroup == 0) { firstGroup = 3; }
        var out = digits.substring(0, firstGroup) as String;
        var i = firstGroup;
        while (i < n) {
            out += "," + (digits.substring(i, i + 3) as String);
            i += 3;
        }
        return out;
    }

    private function formatWhole(v as Double) as String {
        return ((Math.round(v) as Numeric).toNumber()).toString();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var headerH = (safeH * 0.24).toNumber();
        dc.setColor(BG_TOP, BG_TOP);
        dc.fillRectangle(safeX, safeY, safeW, headerH);

        dc.setColor(Graphics.COLOR_WHITE, BG_TOP);
        var text = engine.displayText();
        if ((screen == SCREEN_UNIT_PICK || screen == SCREEN_CUR_LETTER || screen == SCREEN_CUR_RESULTS) && fromUnitKey != null) {
            text = "FROM " + unitLabel(fromUnitKey as String) + "...";
        } else if (screen == SCREEN_RANDOM) {
            text = randStage == 0 ? "MIN? " + text : "MIN " + formatWhole(randMin) + " MAX? " + text;
        } else if (screen == SCREEN_TIP) {
            text = (tipStage == 0 ? "BILL? " : tipStage == 1 ? "TIP%? " : "PPL? ") + text;
        } else if (screen == SCREEN_PCT) {
            if (pctStage == 0) {
                text = "DISCOUNT / MARKUP / MARGIN?";
            } else if (pctStage == 1) {
                text = "BASE? " + text;
            } else {
                text = "PCT? " + text;
            }
        } else if (screen == SCREEN_DATE) {
            if (dateStage == 0) {
                text = "UNTIL / AGE / DIFF?";
            } else if (dateMode == 2) {
                var labels = ["DATE1 Y? ", "DATE1 M? ", "DATE1 D? ", "DATE2 Y? ", "DATE2 M? ", "DATE2 D? "] as Array<String>;
                text = labels[dateStage - 1] + text;
            } else if (dateStage == 1) {
                text = (dateMode == 0 ? "TARGET Y? " : "BIRTH Y? ") + text;
            } else if (dateStage == 2) {
                text = "M? " + text;
            } else {
                text = "D? " + text;
            }
        }
        text = groupThousands(text);
        var font = text.length() > 10 ? Graphics.FONT_TINY : (text.length() > 6 ? Graphics.FONT_SMALL : Graphics.FONT_LARGE);
        dc.drawText(safeX + safeW / 2, safeY + headerH / 2, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var setVars = "";
        var varKeys = engine.variables.keys() as Array<String>;
        for (var vi = 0; vi < varKeys.size(); vi++) {
            setVars += varKeys[vi];
        }
        if (setVars.length() > 0) {
            dc.drawText(safeX, safeY, Graphics.FONT_XTINY, setVars, Graphics.TEXT_JUSTIFY_LEFT);
        }

        var isSmallCellScreen = screen == SCREEN_VAR || screen == SCREEN_ADVANCED || screen == SCREEN_SCIENTIFIC ||
            screen == SCREEN_UNITS || screen == SCREEN_UNIT_PICK || screen == SCREEN_CUR_LETTER || screen == SCREEN_CUR_RESULTS;
        var buttonFont = screen == SCREEN_BASIC ? Graphics.FONT_MEDIUM : (isSmallCellScreen ? Graphics.FONT_TINY : Graphics.FONT_SMALL);
        for (var i = 0; i < buttons.size(); i++) {
            var b = buttons[i];
            var minDim = b.w < b.h ? b.w : b.h;
            var radius = (minDim / 6).toNumber();
            if (radius < 4) {
                radius = 4;
            }
            var maxRadius = ((minDim - 6) / 2).toNumber();
            if (radius > maxRadius) {
                radius = maxRadius;
            }
            if (radius < 0) {
                radius = 0;
            }
            var isSelected = i == selectedIndex;
            var fill = buttonColor(b.action);
            if (isSelected) {
                dc.setColor(ACCENT_SELECT_RING, ACCENT_SELECT_RING);
                dc.fillRoundedRectangle(b.x + 1, b.y + 1, b.w - 2, b.h - 2, radius);
            }
            dc.setColor(fill, fill);
            dc.fillRoundedRectangle(b.x + 3, b.y + 3, b.w - 6, b.h - 6, radius);

            var icon = b.icon;
            var labelColor = fill == ACCENT_OP ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
            if (icon != null) {
                dc.drawBitmap(b.x + (b.w - icon.getWidth()) / 2, b.y + (b.h - icon.getHeight()) / 2, icon);
            } else {
                var labelFont = (screen == SCREEN_BASIC && b.label.equals("MENU")) ? Graphics.FONT_XTINY : buttonFont;
                dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(b.x + b.w / 2, b.y + b.h / 2, labelFont, b.label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }
}

import Toybox.Test;
import Toybox.Lang;
import Toybox.Math;

// Verifies that every visible button is actually tappable at its own
// on-screen center, for both round and rectangular layouts, and for both
// the basic and scientific screens. This is the exact logic behind onTap,
// so a failure here means taps really would miss buttons on-device.
(:test)
function testBasicScreenButtonsAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 0) && checkAllButtonsTappable(logger, true, 0);
}

(:test)
function testScientificScreenButtonsAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 1) && checkAllButtonsTappable(logger, true, 1);
}

(:test)
function testAdvancedScreenButtonsAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 2) && checkAllButtonsTappable(logger, true, 2);
}

(:test)
function testUnitCategoryAndTipScreensAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 3) && checkAllButtonsTappable(logger, true, 3) &&
        checkAllButtonsTappable(logger, false, 8) && checkAllButtonsTappable(logger, true, 8) &&
        checkAllButtonsTappable(logger, false, 9) && checkAllButtonsTappable(logger, true, 9);
}

(:test)
function testMenuScreenButtonsAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 10) && checkAllButtonsTappable(logger, true, 10);
}

(:test)
function testPctAndDateScreensAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 12) && checkAllButtonsTappable(logger, true, 12) &&
        checkAllButtonsTappable(logger, false, 13) && checkAllButtonsTappable(logger, true, 13);
}

(:test)
function testMoreScreenButtonsAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 14) && checkAllButtonsTappable(logger, true, 14);
}

// GRAPH/BASE/COLOR/COUNTER (18/19/20/21) are non-customizable tool screens
// off MORE, same as VAR/NAV - pin that their buttons are actually tappable too.
(:test)
function testGraphBaseColorScreensAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 18) && checkAllButtonsTappable(logger, true, 18) &&
        checkAllButtonsTappable(logger, false, 19) && checkAllButtonsTappable(logger, true, 19) &&
        checkAllButtonsTappable(logger, false, 20) && checkAllButtonsTappable(logger, true, 20) &&
        checkAllButtonsTappable(logger, false, 21) && checkAllButtonsTappable(logger, true, 21);
}

// The FORMULAS (22) and "MORE formulas" (24) category pickers are plain
// grids reachable directly, same as any other fixed tool screen.
(:test)
function testFormulasCategoryScreensAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, 22) && checkAllButtonsTappable(logger, true, 22) &&
        checkAllButtonsTappable(logger, false, 24) && checkAllButtonsTappable(logger, true, 24);
}

// SCREEN_FORMULA_LIST (23) and SCREEN_FORMULA_MORE_LIST (25) need a
// category selected first (via activate()) before there's anything but a
// bare BACK row to lay out - checkAllButtonsTappable() always constructs
// its own fresh view, so it can't be reused here; this inlines the same
// center-hit assertion after picking "Geometry" on each screen.
(:test)
function testFormulaListScreensAreTappable(logger as Test.Logger) as Boolean {
    return checkFormulaListTappable(logger, false, "formulaCat:geom") &&
        checkFormulaListTappable(logger, true, "formulaCat:geom") &&
        checkFormulaListTappable(logger, false, "formulaCatMore:geom") &&
        checkFormulaListTappable(logger, true, "formulaCatMore:geom");
}

function checkFormulaListTappable(logger as Test.Logger, round as Boolean, categoryAction as String) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, round);
    v.activate(new CalcButton("Geometry", categoryAction));
    var buttons = v.getButtons();
    if (buttons.size() == 0) {
        logger.debug("formula list produced zero buttons for '" + categoryAction + "'");
        return false;
    }
    for (var i = 0; i < buttons.size(); i++) {
        var b = buttons[i];
        if (b.w <= 0 || b.h <= 0) {
            logger.debug("formula list button '" + b.label + "' has non-positive size " + b.w + "x" + b.h);
            return false;
        }
        var cx = b.x + b.w / 2;
        var cy = b.y + b.h / 2;
        var idx = v.buttonAt(cx, cy);
        if (idx == null || (idx as Number) != i) {
            logger.debug("formula list button '" + b.label + "' center did not resolve back to index " + i);
            return false;
        }
    }
    return true;
}

// MENU -> FORMULAS -> a category -> its list -> BACK, and the "MORE"
// branch alongside it, following testMenuHubNavigation's pin-the-chain shape.
(:test)
function testFormulasNavigation(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("MENU", "menu"));
    v.activate(new CalcButton("FORM", "formulas"));
    if (v.screen != v.SCREEN_FORMULAS) {
        logger.debug("expected SCREEN_FORMULAS after formulas, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("Geometry", "formulaCat:geom"));
    if (v.screen != v.SCREEN_FORMULA_LIST) {
        logger.debug("expected SCREEN_FORMULA_LIST after formulaCat:geom, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("BACK", "formulaListBack"));
    if (v.screen != v.SCREEN_FORMULAS) {
        logger.debug("expected formula list BACK to return to SCREEN_FORMULAS, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("MORE", "formulasMore"));
    if (v.screen != v.SCREEN_FORMULAS_MORE) {
        logger.debug("expected SCREEN_FORMULAS_MORE after formulasMore, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("Geometry", "formulaCatMore:geom"));
    if (v.screen != v.SCREEN_FORMULA_MORE_LIST) {
        logger.debug("expected SCREEN_FORMULA_MORE_LIST after formulaCatMore:geom, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("BACK", "formulaMoreListBack"));
    if (v.screen != v.SCREEN_FORMULAS_MORE) {
        logger.debug("expected more-list BACK to return to SCREEN_FORMULAS_MORE, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("BACK", "formulas"));
    return v.screen == v.SCREEN_FORMULAS;
}

// Tapping a formula asks each fill-in letter first (like RANDOM's MIN/MAX),
// then inserts the filled-in exercise rather than the bare template.
(:test)
function testCircleAreaFormulaAsksRadiusThenInsertsExercise(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "clear"));
    v.activate(new CalcButton("", "formula:circleArea"));
    if (v.screen != v.SCREEN_FORMULA_INPUT) {
        logger.debug("expected SCREEN_FORMULA_INPUT, got " + v.screen);
        return false;
    }
    return pressAndExpect(logger, v, ["digit:3", "formulaNext"], "π*3^2") &&
        pressAndExpect(logger, v, ["equals"], v.engine.formatNumber((Math.PI.toDouble() as Double) * 9.0d));
}

// Multi-letter formula: each letter asked once, in order; a negative value
// is parenthesized, and an unfinished prefix gets the formula in parens.
(:test)
function testPythagoreanFormulaAsksEachLetterInOrder(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v,
        ["clear", "digit:1", "op:+", "formula:pythagorean", "digit:3", "formulaNext", "op:-", "digit:4", "formulaNext"],
        "1+(sqrt(3^2+(-4)^2))") &&
        pressAndExpect(logger, v, ["equals"], "6");
}

// A formula id that no longer resolves (e.g. a stale seed-picked custom
// formula after the custom list shrank) must fail safe, not crash.
(:test)
function testUnknownFormulaIdFallsBackToBasicScreen(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "formula:doesNotExist"));
    return v.screen == v.SCREEN_BASIC;
}

// +1/-1 tally the running count; RESET zeros it; BACK returns to MORE.
(:test)
function testCounterIncDecAndReset(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "counter"));
    v.activate(new CalcButton("", "counterInc"));
    v.activate(new CalcButton("", "counterInc"));
    v.activate(new CalcButton("", "counterDec"));
    if (!v.counterValueString().equals("1")) {
        logger.debug("expected 1 after +1 +1 -1, got " + v.counterValueString());
        return false;
    }
    v.activate(new CalcButton("", "counterReset"));
    if (!v.counterValueString().equals("0")) {
        logger.debug("expected 0 after RESET, got " + v.counterValueString());
        return false;
    }
    v.activate(new CalcButton("BACK", "counterBack"));
    return v.screen == v.SCREEN_MORE;
}

// "+N" opens a nested keypad (like baseRdx) to type a bulk amount (clamped
// 1-100); ADD applies it once and remembers it as the step that a
// long-press on -1 (see the delegate's onHold) later subtracts in one go.
(:test)
function testCounterMultiAddClampsAndFeedsLongPressDecrement(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "counter"));
    v.activate(new CalcButton("", "counterMulti"));
    v.activate(new CalcButton("", "digit:9"));
    v.activate(new CalcButton("", "digit:9"));
    v.activate(new CalcButton("", "digit:9")); // 999 -> clamped to 100
    v.activate(new CalcButton("", "counterMultiAdd"));
    if (v.screen != v.SCREEN_COUNTER || !v.counterValueString().equals("100")) {
        logger.debug("expected COUNTER at 100 after +N 999 (clamped), got screen " + v.screen + " value " + v.counterValueString());
        return false;
    }
    // Long-press decrement (delegate maps a hold on -1 to counterDecMulti)
    // should subtract the remembered step (100), not just 1.
    v.activate(new CalcButton("-1", "counterDecMulti"));
    if (!v.counterValueString().equals("0")) {
        logger.debug("expected 0 after subtracting the 100 step, got " + v.counterValueString());
        return false;
    }
    // Cancelling out of "+N" entry (BACK) returns to the counter view, not
    // all the way to MORE.
    v.activate(new CalcButton("", "counterMulti"));
    v.activate(new CalcButton("BACK", "counterBack"));
    return v.screen == v.SCREEN_COUNTER;
}

// Typing "X^2" then GRAPH captures that formula, doesn't touch the main
// expression, and BACK returns to MORE (the hub GRAPH is opened from).
(:test)
function testGraphCapturesExpressionAndBackReturnsToMore(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "digit:5"));
    v.activate(new CalcButton("", "graph"));
    if (v.screen != v.SCREEN_GRAPH) {
        logger.debug("expected SCREEN_GRAPH after graph, got " + v.screen);
        return false;
    }
    if (!v.engine.displayText().equals("5")) {
        logger.debug("graph should not alter the main expression, got " + v.engine.displayText());
        return false;
    }
    v.activate(new CalcButton("BACK", "graphBack"));
    return v.screen == v.SCREEN_MORE;
}

// Typing 12, tapping BASE reads it as the seed integer; NOT flips every
// bit (12 -> -13 for a two's-complement Number), and USE splices the
// result back onto the keypad as a plain decimal.
(:test)
function testBaseNotAndUseRoundTrip(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v, ["clear", "digit:1", "digit:2", "base", "baseNot", "baseUse"], "-13");
}

// Shifting 1 left three times is 8, decimal.
(:test)
function testBaseShiftLeft(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v,
        ["clear", "digit:1", "base", "baseShl", "baseShl", "baseShl", "baseUse"], "8");
}

// RDX opens a nested numeric entry for an arbitrary radix (2-36) without
// disturbing baseValue or the main expression; 12 in base 3 is "110".
(:test)
function testBaseCustomRadixConversion(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "digit:1"));
    v.activate(new CalcButton("", "digit:2"));
    v.activate(new CalcButton("", "base"));
    v.activate(new CalcButton("", "baseRdx"));
    v.activate(new CalcButton("", "digit:3"));
    v.activate(new CalcButton("", "baseRdxSet"));
    if (!v.baseCustomString().equals("R3 110")) {
        logger.debug("expected R3 110, got " + v.baseCustomString());
        return false;
    }
    // Cancelling out of radix entry (BACK) returns to the base view rather
    // than exiting all the way to MORE.
    v.activate(new CalcButton("", "baseRdx"));
    v.activate(new CalcButton("BACK", "baseBack"));
    if (v.screen != v.SCREEN_BASE) {
        logger.debug("expected BACK from radix entry to stay on SCREEN_BASE, got " + v.screen);
        return false;
    }
    // BACK from the main base view still exits to MORE, and baseValue
    // itself was never disturbed by the radix sub-flow.
    return pressAndExpect(logger, v, ["baseUse"], "12");
}

// COLOR lives as an "RGB" corner shortcut on the UNITS converter screen
// (see the RGB button block in layoutButtons()), not its own seed-editable
// category - so it's reached via "units" then "color", and BACK from it
// returns to UNITS, same as any other converter sub-flow.
// R=255 G=0 B=0 is pure red -> #FF0000, shown once colorStage hits 3.
(:test)
function testColorRgbEntryProducesHexAndBackReturnsToUnits(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "units"));
    v.activate(new CalcButton("", "color"));
    v.activate(new CalcButton("", "digit:2"));
    v.activate(new CalcButton("", "digit:5"));
    v.activate(new CalcButton("", "digit:5"));
    v.activate(new CalcButton("", "colorNext"));
    v.activate(new CalcButton("", "colorNext")); // G left at 0
    v.activate(new CalcButton("", "colorShow")); // B left at 0
    if (!v.colorHex().equals("#FF0000")) {
        logger.debug("expected #FF0000, got " + v.colorHex());
        return false;
    }
    v.activate(new CalcButton("BACK", "colorBack"));
    return v.screen == v.SCREEN_UNITS;
}

// Opening COLOR from mid-expression ("1+") must not lose that expression -
// a real bug risk here, since "units" already stashed it via its own
// embedded flow before COLOR's keypad ever touches engine.expr.
(:test)
function testColorDoesNotLoseInProgressExpression(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "digit:1"));
    v.activate(new CalcButton("", "op:+"));
    v.activate(new CalcButton("", "units"));
    v.activate(new CalcButton("", "color"));
    v.activate(new CalcButton("", "digit:9"));
    v.activate(new CalcButton("", "colorNext"));
    v.activate(new CalcButton("", "colorNext"));
    v.activate(new CalcButton("", "colorShow"));
    v.activate(new CalcButton("", "colorBack"));
    v.activate(new CalcButton("", "unitCatBack"));
    v.activate(new CalcButton("", "basic"));
    return v.engine.displayText().equals("1+");
}

// PCT+/DATE/VAR moved off the default MENU behind a "MORE" corner button on
// the Scientific screen; this pins that door and its own BACK still works.
(:test)
function testSciMoreNavigatesToOverflowTools(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("fx", "sci"));
    if (v.screen != v.SCREEN_SCIENTIFIC) {
        logger.debug("expected SCREEN_SCIENTIFIC after sci, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("MORE", "more"));
    if (v.screen != v.SCREEN_MORE) {
        logger.debug("expected SCREEN_MORE after more, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("BACK", "moreBack"));
    return v.screen == v.SCREEN_SCIENTIFIC;
}

// The home screen is a plain 4-function calculator with a single "MENU"
// door into every advanced tool; each tool's BACK returns to that menu
// (not to each other), and the menu's own BACK returns home.
(:test)
function testMenuHubNavigation(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("MENU", "menu"));
    if (v.screen != v.SCREEN_MENU) {
        logger.debug("expected SCREEN_MENU after menu, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("VAR", "var"));
    if (v.screen != v.SCREEN_VAR) {
        logger.debug("expected SCREEN_VAR after var, got " + v.screen);
        return false;
    }
    // The var screen's own BACK button now generates plain "menu" (the
    // "varBack" action was folded into it - identical destination, one
    // less action string).
    v.activate(new CalcButton("BACK", "menu"));
    if (v.screen != v.SCREEN_MENU) {
        logger.debug("expected var's BACK to return to SCREEN_MENU, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("fx", "sci"));
    if (v.screen != v.SCREEN_SCIENTIFIC) {
        logger.debug("expected SCREEN_SCIENTIFIC after sci, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("BACK", "menu"));
    if (v.screen != v.SCREEN_MENU) {
        logger.debug("expected scientific BACK to return to SCREEN_MENU, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("BACK", "basic"));
    return v.screen == v.SCREEN_BASIC;
}

// Presses a sequence of actions, then checks what the display shows.
function pressAndExpect(logger as Test.Logger, v as calc_for_garminView, actions as Array<String>, expected as String) as Boolean {
    for (var i = 0; i < actions.size(); i++) {
        v.activate(new CalcButton("", actions[i]));
    }
    var got = v.engine.displayText();
    if (!got.equals(expected)) {
        logger.debug("after " + actions.toString() + " expected " + expected + ", got " + got);
        return false;
    }
    return true;
}

// STO stores the typed value under a name (and shows it back, like "=");
// RCL splices it in at the cursor, so A/B become normal formula building
// blocks - e.g. "A+B".
(:test)
function testVariableStoreRecallAndUseInExpression(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v, ["clear", "digit:5", "sto:A"], "5") &&
        pressAndExpect(logger, v, ["clear", "digit:3", "sto:B"], "3") &&
        pressAndExpect(logger, v, ["clear", "rcl:A", "op:+", "rcl:B", "equals"], "8") &&
        pressAndExpect(logger, v, ["clear", "varClear", "rcl:A"], "0");
}

// RND/TIP/converter are "embedded flows": whatever's already typed (here
// "1+") is stashed while the flow runs on a blank slate, then its result is
// spliced back in exactly where the flow was entered - so a tip split can
// be part of a bigger formula instead of a dead end. 100 + 10% tip split 2
// ways = 55 each -> "1+55".
(:test)
function testTipSplitEmbedsResultAtCursor(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v,
        ["clear", "digit:1", "op:+", "tip", "digit:1", "digit:0", "digit:0", "tipNext", "digit:1", "digit:0", "tipNext", "digit:2", "tipGo"],
        "1+55");
}

// Advanced %: 100 with a 10% discount is 90, spliced into "1+" -> "1+90".
(:test)
function testAdvancedPercentDiscountEmbedsResultAtCursor(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v,
        ["clear", "digit:1", "op:+", "apct", "pctMode:0", "digit:1", "digit:0", "digit:0", "pctNext", "digit:1", "digit:0", "pctGo"],
        "1+90");
}

// "=" records a history entry; opening it shows its solution steps, and
// pasting the final step splices that result back in at the cursor, same
// as Ans.
(:test)
function testHistoryRecordsAndRecallsLastResult(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v,
        ["clear", "digit:1", "digit:2", "op:+", "digit:3", "equals", "op:+", "history", "histOpen:0", "histStep:1"],
        "15+15");
}

// A target date almost 75 years out should always be thousands of days
// away, regardless of what "today" actually is when the test runs.
(:test)
function testDateDaysUntilIsPositiveForAFutureYear(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.activate(new CalcButton("", "date"));
    v.activate(new CalcButton("", "dateMode:0"));
    v.activate(new CalcButton("", "digit:2"));
    v.activate(new CalcButton("", "digit:0"));
    v.activate(new CalcButton("", "digit:9"));
    v.activate(new CalcButton("", "digit:9"));
    v.activate(new CalcButton("", "dateNext"));
    v.activate(new CalcButton("", "digit:1"));
    v.activate(new CalcButton("", "dateNext"));
    v.activate(new CalcButton("", "digit:1"));
    v.activate(new CalcButton("", "dateGo"));
    var got = v.engine.displayText().toNumber();
    if (got == null || (got as Number) < 1000) {
        logger.debug("expected many days until year 2099, got " + v.engine.displayText());
        return false;
    }
    return true;
}

// DIFF mode compares two fixed, typed-in dates rather than "today", so the
// expected day count is deterministic regardless of when the test runs.
// 2024-01-01 -> 2024-01-11 is exactly 10 days (2024 being a leap year
// doesn't matter here, both dates are in January).
(:test)
function testDateDiffBetweenTwoFixedDates(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v,
        ["clear", "date", "dateMode:2",
            "digit:2", "digit:0", "digit:2", "digit:4", "dateNext",
            "digit:1", "dateNext",
            "digit:1", "dateNext",
            "digit:2", "digit:0", "digit:2", "digit:4", "dateNext",
            "digit:1", "dateNext",
            "digit:1", "digit:1", "dateGo"],
        "10");
}

// 12 kph is a 5:00/km pace, and the "m:ss" result converts back.
(:test)
function testPaceConvertsBothWays(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v, ["cat:pace", "digit:1", "digit:2", "unit:kph", "unit:/km"], "(12kph>/km)") &&
        pressAndExpect(logger, v, ["equals"], "5:00") &&
        pressAndExpect(logger, v, ["unit:/km", "unit:kph", "equals"], "12");
}

// A conversion keeps the exercise in the expression, so it can be part of
// a bigger calculation and a compound value gets its own parens.
(:test)
function testConversionIsAnExerciseInsideTheExpression(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v, ["clear", "digit:2", "op:*", "units", "cat:dist", "digit:5", "unit:km", "unit:m"], "2*(5km>m)") &&
        pressAndExpect(logger, v, ["equals"], "10000") &&
        pressAndExpect(logger, v, ["clear", "digit:2", "op:+", "digit:3", "units", "cat:weight", "unit:kg", "unit:g"], "((2+3)kg>g)") &&
        pressAndExpect(logger, v, ["equals"], "5000");
}

// History's step-by-step view collapses a conversion like a function call.
(:test)
function testConversionCollapsesInSolutionSteps(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    var got = v.engine.computeSolutionSteps("2*(5km>m)", null).toString();
    if (!got.equals("[2*(5km>m), 2*5000, 10000]")) {
        logger.debug("unexpected steps " + got);
        return false;
    }
    return true;
}

(:test)
function testNewUnitCategories(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v, ["clear", "cat:area", "digit:1", "unit:ha", "unit:m2", "equals"], "10000") &&
        pressAndExpect(logger, v, ["clear", "units", "cat:time", "digit:2", "unit:hr", "unit:min", "equals"], "120") &&
        pressAndExpect(logger, v, ["clear", "units", "cat:temp", "digit:0", "unit:c", "unit:K", "equals"], "273.15");
}

(:test)
function testTapOutsideAnyButtonMisses(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    var idx = v.buttonAt(-10, -10);
    if (idx != null) {
        logger.debug("expected a miss outside the screen, got index " + idx);
        return false;
    }
    return true;
}

(:test)
function testDigitButtonDispatchesToEngine(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    var buttons = v.getButtons();
    var found = false;
    for (var i = 0; i < buttons.size(); i++) {
        if (buttons[i].action.equals("digit:7")) {
            var b = buttons[i];
            var cx = b.x + b.w / 2;
            var cy = b.y + b.h / 2;
            var idx = v.buttonAt(cx, cy);
            if (idx == null || !buttons[idx as Number].action.equals("digit:7")) {
                logger.debug("tap on 7's own center did not resolve to the 7 button");
                return false;
            }
            v.activate(buttons[idx as Number]);
            found = true;
        }
    }
    if (!found) {
        logger.debug("no digit:7 button found in basic layout");
        return false;
    }
    return v.engine.displayText().equals("7");
}

// Currency conversion uses fetched/stored rates rather than the static
// unitFactor table; this pins the USD-based math (v / rate[from] *
// rate[to]) against a known rate set, independent of Storage/network state.
(:test)
function testCurrencyConversionUsesInjectedRates(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.setCurrencyRatesForTest({
        "USD" => 1.0d,
        "EUR" => 0.5d,
    } as Dictionary<String, Double>);
    v.activate(new CalcButton("CUR", "cat:cur"));
    v.engine.appendDigit("1");
    v.engine.appendDigit("0");
    v.activate(new CalcButton("USD", "unit:USD"));
    v.activate(new CalcButton("EUR", "unit:EUR"));
    if (!v.engine.expr.equals("(10USD>EUR)")) {
        logger.debug("expected the exercise (10USD>EUR), got " + v.engine.expr);
        return false;
    }
    v.activate(new CalcButton("=", "equals"));
    var got = v.engine.displayText();
    if (!got.equals("5")) {
        logger.debug("10 USD at 0.5 EUR/USD should convert to 5, got " + got);
        return false;
    }
    return true;
}

// The "OTHER" autocomplete flow (letter -> matching codes -> pick) must
// preserve an in-progress FROM pick across screen changes, since goToScreen
// (unlike switchScreen) is used precisely to avoid losing it.
(:test)
function testCurrencyAutocompletePreservesFromPick(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.setCurrencyRatesForTest({
        "USD" => 1.0d,
        "EUR" => 0.5d,
        "GBP" => 0.4d,
    } as Dictionary<String, Double>);
    v.activate(new CalcButton("CUR", "cat:cur"));
    v.engine.appendDigit("2");
    v.engine.appendDigit("0");
    v.activate(new CalcButton("USD", "unit:USD"));       // FROM = USD
    v.activate(new CalcButton("OTHER", "curOther"));      // -> letter screen
    if (v.screen != v.SCREEN_CUR_LETTER) {
        logger.debug("expected SCREEN_CUR_LETTER after OTHER, got " + v.screen);
        return false;
    }
    v.activate(new CalcButton("G", "curletter:G"));       // single match -> GBP auto-selected
    v.activate(new CalcButton("=", "equals"));
    var got = v.engine.displayText();
    if (!got.equals("8")) {
        logger.debug("20 USD at 0.4 GBP/USD should convert to 8, got " + got);
        return false;
    }
    // A completed conversion now exits the flow and splices the result back
    // into the (empty, here) expression that was active before OTHER was
    // pressed, landing on the basic screen rather than staying on the picker.
    if (v.screen != v.SCREEN_BASIC) {
        logger.debug("expected to land back on SCREEN_BASIC, got " + v.screen);
        return false;
    }
    return true;
}

function checkAllButtonsTappable(logger as Test.Logger, round as Boolean, screen as Number) as Boolean {
    var v = new calc_for_garminView();
    if (screen != 0) {
        v.switchScreen(screen);
    }
    v.layoutForSize(260, 260, round);
    var buttons = v.getButtons();
    if (buttons.size() == 0) {
        logger.debug("layout produced zero buttons");
        return false;
    }
    for (var i = 0; i < buttons.size(); i++) {
        var b = buttons[i];
        if (b.w <= 0 || b.h <= 0) {
            logger.debug("button '" + b.label + "' has non-positive size " + b.w + "x" + b.h);
            return false;
        }
        var cx = b.x + b.w / 2;
        var cy = b.y + b.h / 2;
        var idx = v.buttonAt(cx, cy);
        if (idx == null) {
            logger.debug("button '" + b.label + "' center (" + cx + "," + cy + ") does not hit any button (round=" + round + ")");
            return false;
        }
        if ((idx as Number) != i) {
            logger.debug("button '" + b.label + "' center resolved to a different button index " + idx + " instead of " + i);
            return false;
        }
    }
    return true;
}

// The letter screen used to call Array.sort(), which only exists from CIQ
// 3.4.0 and crashed on 3.3 devices (vivoactive 4s). This pins both that the
// screen builds at all and that the letters come out sorted.
(:test)
function testCurrencyLetterScreenIsSortedWithoutArraySort(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    v.setCurrencyRatesForTest({
        "ZAR" => 18.0d,
        "AUD" => 1.5d,
        "MXN" => 17.0d,
        "AED" => 3.6d,
    } as Dictionary<String, Double>);
    v.activate(new CalcButton("CUR", "cat:cur"));
    v.activate(new CalcButton("OTHER", "curOther"));
    var buttons = v.getButtons();
    var letters = "";
    for (var i = 0; i < buttons.size(); i++) {
        if (buttons[i].action.find("curletter:") == 0) {
            letters += buttons[i].label;
        }
    }
    if (!letters.equals("AMZ")) {
        logger.debug("expected sorted letters AMZ, got " + letters);
        return false;
    }
    return true;
}

(:test)
function testEasterEggsWhenEnabledAndDisabled(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);

    // When disabled, +6%+ does not trigger easter egg
    SeedConfig.get().easterEggs = false;
    v.engine.clear();
    v.activate(new CalcButton("+", "op:+"));
    v.activate(new CalcButton("6", "digit:6"));
    v.activate(new CalcButton("%", "op:%"));
    v.activate(new CalcButton("+", "op:+"));
    v.activate(new CalcButton("=", "equals"));
    if (v.popupKind != null) {
        logger.debug("Easter eggs should not trigger when disabled");
        return false;
    }

    // When enabled, +6%+ -> popupKind = "hebrew_profit"
    SeedConfig.get().easterEggs = true;
    v.engine.clear();
    v.activate(new CalcButton("+", "op:+"));
    v.activate(new CalcButton("6", "digit:6"));
    v.activate(new CalcButton("%", "op:%"));
    v.activate(new CalcButton("+", "op:+"));
    v.activate(new CalcButton("=", "equals"));
    if (v.popupKind == null || !(v.popupKind as String).equals("hebrew_profit")) {
        logger.debug("Expected popupKind 'hebrew_profit', got: " + v.popupKind);
        return false;
    }
    // Test dismiss
    v.dismissPopup();
    if (v.popupKind != null) {
        logger.debug("Expected popup to be dismissed");
        return false;
    }

    // When enabled, 42 -> popupKind = "answer_to_life"
    v.engine.clear();
    v.activate(new CalcButton("4", "digit:4"));
    v.activate(new CalcButton("2", "digit:2"));
    v.activate(new CalcButton("=", "equals"));
    if (v.popupKind == null || !(v.popupKind as String).equals("answer_to_life")) {
        logger.debug("Expected popupKind 'answer_to_life', got: " + v.popupKind);
        return false;
    }
    v.dismissPopup();

    // Reset back to default
    SeedConfig.get().easterEggs = false;
    return true;
}


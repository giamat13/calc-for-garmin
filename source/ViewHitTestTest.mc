import Toybox.Test;
import Toybox.Lang;

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

// 12 kph is a 5:00/km pace, and the "m:ss" result converts back.
(:test)
function testPaceConvertsBothWays(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v, ["cat:pace", "digit:1", "digit:2", "unit:kph", "unit:/km"], "5:00") &&
        pressAndExpect(logger, v, ["unit:/km", "unit:kph"], "12");
}

(:test)
function testNewUnitCategories(logger as Test.Logger) as Boolean {
    var v = new calc_for_garminView();
    v.layoutForSize(260, 260, false);
    return pressAndExpect(logger, v, ["clear", "cat:area", "digit:1", "unit:ha", "unit:m2"], "10000") &&
        pressAndExpect(logger, v, ["clear", "units", "cat:time", "digit:2", "unit:hr", "unit:min"], "120") &&
        pressAndExpect(logger, v, ["clear", "units", "cat:temp", "digit:0", "unit:c", "unit:K"], "273.15");
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

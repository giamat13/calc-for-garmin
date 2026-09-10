import Toybox.Test;
import Toybox.Lang;

// Verifies that every visible button is actually tappable at its own
// on-screen center, for both round and rectangular layouts, and for both
// the basic and scientific screens. This is the exact logic behind onTap,
// so a failure here means taps really would miss buttons on-device.
(:test)
function testBasicScreenButtonsAreTappable(logger as Test.Logger) as Boolean {
    return checkAllButtonsTappable(logger, false, false) && checkAllButtonsTappable(logger, true, false);
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

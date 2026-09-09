import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class CalcButton {
    var label as String;
    var action as String;
    var x as Number = 0;
    var y as Number = 0;
    var w as Number = 0;
    var h as Number = 0;

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

    var engine as CalculatorEngine = new CalculatorEngine();
    var screen as Number = SCREEN_BASIC;
    var selectedIndex as Number = 0;
    private var buttons as Array<CalcButton> = [] as Array<CalcButton>;

    // Safe content area: on round watches a full-width row near the top/bottom
    // edge gets chopped off by the bezel, so content is confined to the
    // largest square that is guaranteed to stay inside the circle.
    private var safeX as Number = 0;
    private var safeY as Number = 0;
    private var safeW as Number = 0;
    private var safeH as Number = 0;

    function initialize() {
        View.initialize();
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

    // Basic screen: everything needed for everyday arithmetic, 5 cols x 4 rows.
    private function basicButtons() as Array<CalcButton> {
        return [
            new CalcButton("C", "clear"), new CalcButton("DEL", "back"), new CalcButton("%", "op:%"), new CalcButton("/", "op:/"), new CalcButton("fx", "sci"),
            new CalcButton("7", "digit:7"), new CalcButton("8", "digit:8"), new CalcButton("9", "digit:9"), new CalcButton("*", "op:*"), new CalcButton(".", "digit:."),
            new CalcButton("4", "digit:4"), new CalcButton("5", "digit:5"), new CalcButton("6", "digit:6"), new CalcButton("-", "op:-"), new CalcButton("0", "digit:0"),
            new CalcButton("1", "digit:1"), new CalcButton("2", "digit:2"), new CalcButton("3", "digit:3"), new CalcButton("+", "op:+"), new CalcButton("=", "equals"),
        ] as Array<CalcButton>;
    }

    // Scientific screen: functions, parentheses and general powers, 4 cols x 5 rows.
    private function scientificButtons() as Array<CalcButton> {
        return [
            new CalcButton("sin", "func:sin"), new CalcButton("cos", "func:cos"), new CalcButton("tan", "func:tan"), new CalcButton("sqrt", "func:sqrt"),
            new CalcButton("log", "func:log"), new CalcButton("ln", "func:ln"), new CalcButton("x2", "sqr"), new CalcButton("x", "const:X"),
            new CalcButton("(", "open"), new CalcButton(")", "close"), new CalcButton("^", "op:^"), new CalcButton("pi", "const:π"),
            new CalcButton("e", "const:e"), new CalcButton("C", "clear"), new CalcButton("DEL", "back"), new CalcButton("ADV", "adv"),
            new CalcButton("BACK", "basic"),
        ] as Array<CalcButton>;
    }

    // Advanced screen: inverse trig, roots, integer/rounding ops and the
    // ×10^x shortcut for entering numbers in scientific notation, 4 cols x 4 rows.
    private function advancedButtons() as Array<CalcButton> {
        return [
            new CalcButton("asin", "func:asin"), new CalcButton("acos", "func:acos"), new CalcButton("atan", "func:atan"), new CalcButton("x!", "fact"),
            new CalcButton("1/x", "inv"), new CalcButton("cbrt", "func:cbrt"), new CalcButton("|x|", "func:abs"), new CalcButton("mod", "op:mod"),
            new CalcButton("EE", "ee"), new CalcButton("x3", "cube"), new CalcButton("floor", "func:floor"), new CalcButton("ceil", "func:ceil"),
            new CalcButton("C", "clear"), new CalcButton("DEL", "back"), new CalcButton("10x", "pow10"), new CalcButton("BACK", "sci"),
        ] as Array<CalcButton>;
    }

    private function layoutButtons() as Void {
        var defs = basicButtons();
        var cols = 5;
        var rows = 4;
        if (screen == SCREEN_SCIENTIFIC) {
            defs = scientificButtons();
            cols = 4;
            rows = 5;
        } else if (screen == SCREEN_ADVANCED) {
            defs = advancedButtons();
            cols = 4;
            rows = 4;
        }

        var headerH = (safeH * 0.24).toNumber();
        var gridTop = safeY + headerH;
        var gridH = safeH - headerH;
        var cellW = safeW / cols;
        var cellH = gridH / rows;

        for (var i = 0; i < defs.size(); i++) {
            var row = i / cols;
            var col = i % cols;
            var b = defs[i];
            b.x = safeX + col * cellW;
            b.y = gridTop + row * cellH;
            b.w = cellW;
            b.h = cellH;
        }
        buttons = defs;
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
        } else if (action.equals("adv")) {
            switchScreen(SCREEN_ADVANCED);
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
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var text = engine.displayText();
        // Regular text fonts, not FONT_NUMBER_*: the expression can contain
        // letters and symbols (X, =, sin, etc.), and the digit-only number
        // fonts have no glyphs for those.
        var font = text.length() > 10 ? Graphics.FONT_TINY : (text.length() > 6 ? Graphics.FONT_SMALL : Graphics.FONT_LARGE);
        var headerH = (safeH * 0.24).toNumber();
        dc.drawText(safeX + safeW / 2, safeY + headerH / 2, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var buttonFont = screen == SCREEN_BASIC ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        for (var i = 0; i < buttons.size(); i++) {
            var b = buttons[i];
            var isSelected = i == selectedIndex;
            var fill = isSelected ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY;
            dc.setColor(fill, fill);
            dc.fillRectangle(b.x + 2, b.y + 2, b.w - 4, b.h - 4);

            dc.setColor(Graphics.COLOR_LT_GRAY, fill);
            dc.drawRectangle(b.x + 2, b.y + 2, b.w - 4, b.h - 4);

            var textColor = isSelected ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
            dc.setColor(textColor, fill);
            dc.drawText(b.x + b.w / 2, b.y + b.h / 2, buttonFont, b.label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function onHide() as Void {
    }

}

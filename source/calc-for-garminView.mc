import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

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

    var engine as CalculatorEngine = new CalculatorEngine();
    var scientific as Boolean = false;
    var selectedIndex as Number = 0;
    private var buttons as Array<CalcButton> = [] as Array<CalcButton>;
    private var screenWidth as Number = 0;
    private var screenHeight as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        screenWidth = dc.getWidth();
        screenHeight = dc.getHeight();
        layoutButtons(screenWidth, screenHeight);
    }

    function onShow() as Void {
    }

    private function basicButtons() as Array<CalcButton> {
        return [
            new CalcButton("C", "clear"), new CalcButton("⌫", "back"), new CalcButton("%", "percent"), new CalcButton("÷", "op:/"),
            new CalcButton("7", "digit:7"), new CalcButton("8", "digit:8"), new CalcButton("9", "digit:9"), new CalcButton("×", "op:*"),
            new CalcButton("4", "digit:4"), new CalcButton("5", "digit:5"), new CalcButton("6", "digit:6"), new CalcButton("−", "op:-"),
            new CalcButton("1", "digit:1"), new CalcButton("2", "digit:2"), new CalcButton("3", "digit:3"), new CalcButton("+", "op:+"),
            new CalcButton("fx", "sci"), new CalcButton("0", "digit:0"), new CalcButton(".", "digit:."), new CalcButton("=", "equals"),
        ] as Array<CalcButton>;
    }

    private function scientificButtons() as Array<CalcButton> {
        return [
            new CalcButton("sin", "un:sin"), new CalcButton("cos", "un:cos"), new CalcButton("tan", "un:tan"),
            new CalcButton("log", "un:log"), new CalcButton("ln", "un:ln"), new CalcButton("√", "un:sqrt"),
            new CalcButton("π", "const:pi"), new CalcButton("e", "const:e"), new CalcButton("x²", "un:sqr"),
            new CalcButton("1/x", "un:inv"), new CalcButton("x^y", "op:^"), new CalcButton("←", "basic"),
        ] as Array<CalcButton>;
    }

    private function layoutButtons(width as Number, height as Number) as Void {
        var displayH = (height * 0.28).toNumber();
        var gridTop = displayH;
        var gridH = height - gridTop;

        var defs = scientific ? scientificButtons() : basicButtons();
        var cols = scientific ? 3 : 4;
        var rows = scientific ? 4 : 5;
        var cellW = width / cols;
        var cellH = gridH / rows;

        for (var i = 0; i < defs.size(); i++) {
            var row = i / cols;
            var col = i % cols;
            var b = defs[i];
            b.x = col * cellW;
            b.y = gridTop + row * cellH;
            b.w = cellW;
            b.h = cellH;
            defs[i] = b;
        }
        buttons = defs;
        if (selectedIndex >= buttons.size()) {
            selectedIndex = 0;
        }
    }

    function getButtons() as Array<CalcButton> {
        return buttons;
    }

    function switchScreen(sci as Boolean) as Void {
        scientific = sci;
        selectedIndex = 0;
        layoutButtons(screenWidth, screenHeight);
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
        } else if (action.equals("percent")) {
            engine.percent();
            return;
        } else if (action.equals("equals")) {
            engine.equalsPressed();
            return;
        } else if (action.equals("sci")) {
            switchScreen(true);
            return;
        } else if (action.equals("basic")) {
            switchScreen(false);
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
            engine.inputDigit(value);
        } else if (prefix.equals("op")) {
            engine.setOperator(value);
        } else if (prefix.equals("un")) {
            engine.unary(value);
        } else if (prefix.equals("const")) {
            engine.constant(value);
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var displayH = (dc.getHeight() * 0.28).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var font = engine.display.length() > 8 ? Graphics.FONT_NUMBER_MILD : Graphics.FONT_NUMBER_MEDIUM;
        dc.drawText(width / 2, displayH / 2, font, engine.display, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        for (var i = 0; i < buttons.size(); i++) {
            var b = buttons[i];
            var fill = buttonColor(b.action);
            if (i == selectedIndex) {
                fill = Graphics.COLOR_YELLOW;
            }
            dc.setColor(fill, fill);
            dc.fillRectangle(b.x + 2, b.y + 2, b.w - 4, b.h - 4);

            dc.setColor(Graphics.COLOR_LT_GRAY, fill);
            dc.drawRectangle(b.x + 2, b.y + 2, b.w - 4, b.h - 4);

            var textColor = (i == selectedIndex) ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
            dc.setColor(textColor, fill);
            dc.drawText(b.x + b.w / 2, b.y + b.h / 2, Graphics.FONT_MEDIUM, b.label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function buttonColor(action as String) as Graphics.ColorType {
        if (action.equals("equals")) {
            return Graphics.COLOR_DK_GREEN;
        }
        if (action.find("op:") == 0 || action.equals("sci") || action.equals("basic")) {
            return Graphics.COLOR_ORANGE;
        }
        if (action.equals("clear") || action.equals("back") || action.equals("percent")) {
            return Graphics.COLOR_DK_GRAY;
        }
        return Graphics.COLOR_DK_BLUE;
    }

    function onHide() as Void {
    }

}

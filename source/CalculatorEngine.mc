import Toybox.Lang;
import Toybox.Math;

// Text-expression calculator: button presses build up a formula string
// (so parentheses and arbitrary powers work naturally), evaluated by
// ExprParser on "=".
class CalculatorEngine {

    var expr as String = "";
    var errorState as Boolean = false;
    private var justEvaluated as Boolean = false;

    // Cursor position for arrow-key editing. Typing normally keeps it at
    // expr.length() (so displayText() shows nothing extra); moving it left
    // is what lets you insert into the middle of an expression - e.g. build
    // "1+" then embed a random/tip/converted value right there.
    var cursorPos as Number = 0;

    // Named variables (A/B/C/D - see calc_for_garminView's VAR screen),
    // usable directly in a formula like a constant, e.g. "A+B*2".
    var variables as Dictionary<String, Double> = {} as Dictionary<String, Double>;

    function initialize() {
    }

    function displayText() as String {
        if (errorState) {
            return "Error";
        }
        if (expr.length() == 0) {
            return "0";
        }
        if (cursorPos == expr.length()) {
            return expr;
        }
        return (expr.substring(0, cursorPos) as String) + "|" + (expr.substring(cursorPos, expr.length()) as String);
    }

    private function insertAtCursor(text as String) as Void {
        expr = (expr.substring(0, cursorPos) as String) + text + (expr.substring(cursorPos, expr.length()) as String);
        cursorPos += text.length();
    }

    // Inserts raw text at the cursor with none of appendDigit's "start fresh
    // after =" logic - used to embed a random/tip/unit-conversion result
    // back into an expression that was already being built.
    function insertRaw(text as String) as Void {
        insertAtCursor(text);
    }

    function moveCursorLeft() as Void {
        if (cursorPos > 0) {
            cursorPos -= 1;
        }
        justEvaluated = false;
    }

    function moveCursorRight() as Void {
        if (cursorPos < expr.length()) {
            cursorPos += 1;
        }
        justEvaluated = false;
    }

    function appendDigit(d as String) as Void {
        resetIfNeeded(true);
        insertAtCursor(d);
    }

    function appendOperator(op as String) as Void {
        resetIfNeeded(false);
        insertAtCursor(op);
    }

    function appendFunction(name as String) as Void {
        resetIfNeeded(true);
        insertAtCursor(name + "(");
    }

    function appendConstant(sym as String) as Void {
        resetIfNeeded(true);
        insertAtCursor(sym);
    }

    function openParen() as Void {
        resetIfNeeded(true);
        insertAtCursor("(");
    }

    function closeParen() as Void {
        if (errorState) {
            return;
        }
        insertAtCursor(")");
    }

    // Wrap the whole formula so far, e.g. "3+4" -> "(3+4)^2".
    function wrapSquare() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "(" + expr + ")^2";
        justEvaluated = false;
        cursorPos = expr.length();
    }

    function wrapCube() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "(" + expr + ")^3";
        justEvaluated = false;
        cursorPos = expr.length();
    }

    function wrapInverse() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "1/(" + expr + ")";
        justEvaluated = false;
        cursorPos = expr.length();
    }

    function wrapPow10() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "10^(" + expr + ")";
        justEvaluated = false;
        cursorPos = expr.length();
    }

    function wrapFactorial() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "fact(" + expr + ")";
        justEvaluated = false;
        cursorPos = expr.length();
    }

    // Evaluate the current expression and return the numeric result without
    // changing the display.  Returns null (and sets errorState) on failure.
    // Used by the unit-converter screen.
    function evaluateToDouble() as Double? {
        if (errorState || expr.length() == 0) {
            return null;
        }
        var parser = new ExprParser(closeUnmatchedParens(expr), 0.0d, variables);
        var result = parser.parse();
        if (parser.error) {
            errorState = true;
            return null;
        }
        return result;
    }

    // Replace the current expression with a pre-computed numeric result.
    // Used by the unit-converter screen after applying a conversion factor.
    function setResult(v as Double) as Void {
        expr = formatNumber(v);
        errorState = false;
        justEvaluated = true;
        cursorPos = expr.length();
    }

    // Like setResult, for results that aren't a plain number (pace "5:30").
    function setResultText(s as String) as Void {
        expr = s;
        errorState = false;
        justEvaluated = true;
        cursorPos = expr.length();
    }

    // Evaluates the current formula and stores it under a named variable
    // (see `variables`), showing the result - like pressing "=" first.
    function storeVar(name as String) as Double? {
        var vOrNull = evaluateToDouble();
        if (vOrNull == null) {
            return null;
        }
        variables[name] = vOrNull as Double;
        setResult(vOrNull as Double);
        return vOrNull;
    }

    function recallVar(name as String) as Void {
        resetIfNeeded(true);
        var v = variables.hasKey(name) ? variables[name] as Double : 0.0d;
        var s = formatNumber(v);
        insertAtCursor(v < 0.0d ? "(" + s + ")" : s);
    }

    // Raw text insertion for things like the "×10^" scientific-notation
    // shortcut, which don't fit the digit/operator/function/constant shapes.
    function appendRaw(text as String) as Void {
        resetIfNeeded(true);
        insertAtCursor(text);
    }

    function backspace() as Void {
        if (errorState) {
            clear();
            return;
        }
        if (cursorPos > 0) {
            expr = (expr.substring(0, cursorPos - 1) as String) + (expr.substring(cursorPos, expr.length()) as String);
            cursorPos -= 1;
        }
        justEvaluated = false;
    }

    function clear() as Void {
        expr = "";
        errorState = false;
        justEvaluated = false;
        cursorPos = 0;
    }

    // "=" does double duty when the formula has an unknown letter: the first
    // press inserts "=" (so you can type the right-hand side), the second
    // solves the equation, e.g. "2X+3" -> "=" -> "2X+3=7" -> "=" -> "X=2".
    // Any single letter works (X, Y, Z, A, ...) as long as it isn't already
    // a stored variable (see `variables`) - once stored, it's a given value
    // like any other, not something to solve for.
    function evaluate() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        var unknown = findUnknownLetter(expr);
        if (unknown != null) {
            if (expr.find("=") == null) {
                expr = expr + "=";
                justEvaluated = false;
                cursorPos = expr.length();
            } else {
                solveFor(unknown as String);
            }
            return;
        }
        var parser = new ExprParser(closeUnmatchedParens(expr), 0.0d, variables);
        var result = parser.parse();
        if (parser.error) {
            errorState = true;
            return;
        }
        expr = formatNumber(result);
        justEvaluated = true;
        cursorPos = expr.length();
    }

    // First bare single-letter identifier in s that isn't "e" (the constant)
    // and isn't already a stored variable - that's the equation's unknown.
    private function findUnknownLetter(s as String) as String? {
        var i = 0;
        while (i < s.length()) {
            var c = s.substring(i, i + 1) as String;
            if (!isAsciiLetter(c)) {
                i += 1;
                continue;
            }
            var start = i;
            while (i < s.length() && isAsciiLetter(s.substring(i, i + 1) as String)) {
                i += 1;
            }
            var ident = s.substring(start, i) as String;
            if (ident.length() == 1 && !(ident.toLower() as String).equals("e") && !variables.hasKey(ident)) {
                return ident;
            }
        }
        return null;
    }

    private function isAsciiLetter(c as String) as Boolean {
        var code = (c.toCharArray()[0] as Char).toNumber();
        return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    }

    // Linear-equation solver: since f(letter) = LHS - RHS is a straight line
    // for any equation built only from +,-,*,/,^ with constant exponents,
    // two sample points fully determine it (f(v) = a*v + b), so v = -b/a. A
    // third sample point catches non-linear formulas instead of silently
    // returning a wrong answer.
    private function solveFor(letter as String) as Void {
        var eqIdxOrNull = expr.find("=");
        if (eqIdxOrNull == null) {
            errorState = true;
            return;
        }
        var eqIdx = eqIdxOrNull as Number;
        var lhs = closeUnmatchedParens(expr.substring(0, eqIdx) as String);
        var rhs = closeUnmatchedParens(expr.substring(eqIdx + 1, expr.length()) as String);
        if (lhs.length() == 0 || rhs.length() == 0) {
            errorState = true;
            return;
        }

        var f0 = evalDiff(letter, lhs, rhs, 0.0d);
        var f1 = evalDiff(letter, lhs, rhs, 1.0d);
        var f2 = evalDiff(letter, lhs, rhs, 2.0d);
        if (f0 == null || f1 == null || f2 == null) {
            errorState = true;
            return;
        }
        var b = f0 as Double;
        var a = (f1 as Double) - b;
        if (a == 0.0d) {
            errorState = true;
            return;
        }
        var residual = (f2 as Double) - (2.0d * a + b);
        if (residual < 0.0d) {
            residual = -residual;
        }
        if (residual > 0.0001d) {
            errorState = true;
            return;
        }
        expr = letter + "=" + formatNumber(-b / a);
        justEvaluated = true;
        cursorPos = expr.length();
    }

    // Substitutes `trial` for `letter` via a scratch copy of `variables`
    // (never mutating the persistent one) - plus the legacy xVal slot, since
    // ExprParser resolves a bare "x"/"X" from that before consulting
    // `variables` at all.
    private function evalDiff(letter as String, lhs as String, rhs as String, trial as Double) as Double? {
        var scratch = {} as Dictionary<String, Double>;
        var keys = variables.keys();
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i] as String;
            scratch[k] = variables[k] as Double;
        }
        scratch[letter] = trial;
        var xArg = (letter.toLower() as String).equals("x") ? trial : 0.0d;
        var pl = new ExprParser(lhs, xArg, scratch);
        var l = pl.parse();
        if (pl.error) {
            return null;
        }
        var pr = new ExprParser(rhs, xArg, scratch);
        var r = pr.parse();
        if (pr.error) {
            return null;
        }
        return l - r;
    }

    private function resetIfNeeded(clearOnEval as Boolean) as Void {
        if (errorState) {
            clear();
        } else if (justEvaluated && clearOnEval) {
            clear();
        } else {
            justEvaluated = false;
        }
    }

    private function closeUnmatchedParens(s as String) as String {
        var open = 0;
        for (var i = 0; i < s.length(); i++) {
            var c = s.substring(i, i + 1) as String;
            if (c.equals("(")) {
                open++;
            } else if (c.equals(")")) {
                open--;
            }
        }
        var out = s;
        while (open > 0) {
            out = out + ")";
            open--;
        }
        return out;
    }

    function formatNumber(v as Double) as String {
        var av = v < 0.0d ? -v : v;
        if (av != 0.0d && (av >= 1000000000.0d || av < 0.0001d)) {
            return v.format("%.4e") as String;
        }
        var s = v.format("%.6f") as String;
        if (s.find(".") != null) {
            while ((s.substring(s.length() - 1, s.length()) as String).equals("0")) {
                s = s.substring(0, s.length() - 1) as String;
            }
            if ((s.substring(s.length() - 1, s.length()) as String).equals(".")) {
                s = s.substring(0, s.length() - 1) as String;
            }
        }
        if (s.length() > 12) {
            return v.format("%.4e") as String;
        }
        return s;
    }
}

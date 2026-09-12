import Toybox.Lang;
import Toybox.Math;
import Toybox.Application.Storage;

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

    // Named variables - any letter typed via the VAR screen becomes one
    // once it's solved for via an equation (see solveEquation()) - usable
    // directly in a formula like a constant, e.g. "B+D*2". Persisted so
    // they survive leaving and returning to the calculator, not just
    // switching screens.
    var variables as Dictionary<String, Double> = {} as Dictionary<String, Double>;

    // Whether the last "=" result is currently shown as a/b instead of a
    // decimal - see toggleFraction().
    private var fractionMode as Boolean = false;

    function initialize() {
        var stored = Storage.getValue("calcVariables");
        if (stored != null) {
            variables = stored as Dictionary<String, Double>;
        }
    }

    private function persistVariables() as Void {
        Storage.setValue("calcVariables", variables);
    }

    function clearVariables() as Void {
        variables = {} as Dictionary<String, Double>;
        persistVariables();
    }

    // Last plain "=" result, for the ANS button.
    var lastAnswer as Double = 0.0d;

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

    // Auto-nesting brackets: one button picks the glyph by how deep the
    // cursor already sits - (), then [], then {} for anything nested
    // deeper than that.
    function openParen() as Void {
        resetIfNeeded(true);
        var depth = openBracketStack(expr.substring(0, cursorPos) as String).size();
        insertAtCursor(depth == 0 ? "(" : (depth == 1 ? "[" : "{"));
    }

    // Closes whichever bracket type is currently innermost at the cursor,
    // so the depth-based open button and this one always pair correctly.
    function closeParen() as Void {
        if (errorState) {
            return;
        }
        var stack = openBracketStack(expr.substring(0, cursorPos) as String);
        insertAtCursor(stack.size() > 0 ? closeFor(stack[stack.size() - 1]) : ")");
    }

    // The still-open brackets before `s`, outermost first - i.e. what you'd
    // need to close, in order, to fully close `s`.
    private function openBracketStack(s as String) as Array<String> {
        var stack = [] as Array<String>;
        for (var i = 0; i < s.length(); i++) {
            var c = s.substring(i, i + 1) as String;
            if (c.equals("(") || c.equals("[") || c.equals("{")) {
                stack.add(c);
            } else if ((c.equals(")") || c.equals("]") || c.equals("}")) && stack.size() > 0) {
                var popped = [] as Array<String>;
                for (var j = 0; j < stack.size() - 1; j++) {
                    popped.add(stack[j]);
                }
                stack = popped;
            }
        }
        return stack;
    }

    private function closeFor(open as String) as String {
        if (open.equals("[")) {
            return "]";
        }
        if (open.equals("{")) {
            return "}";
        }
        return ")";
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
        persistVariables();
        setResult(vOrNull as Double);
        return vOrNull;
    }

    function recallVar(name as String) as Void {
        resetIfNeeded(true);
        var v = variables.hasKey(name) ? variables[name] as Double : 0.0d;
        var s = formatNumber(v);
        insertAtCursor(v < 0.0d ? "(" + s + ")" : s);
    }

    // Inserts an arbitrary computed value at the cursor, like any other
    // value being typed - used by Ans and by recalling a history entry.
    function insertValue(v as Double) as Void {
        resetIfNeeded(true);
        var s = formatNumber(v);
        insertAtCursor(v < 0.0d ? "(" + s + ")" : s);
    }

    // Inserts the last plain "=" result at the cursor.
    function insertAns() as Void {
        insertValue(lastAnswer);
    }

    // The EQ button inserts a literal "=" (building "LHS=RHS" to solve);
    // the "=" button (evaluate()) then solves it. Whether "=" solves an
    // equation or does a plain calculation depends only on whether the
    // expression actually contains "=" - not on a variable's prior state -
    // so a known variable can always be redefined by just typing a new
    // equation for it.
    function insertEquals() as Void {
        resetIfNeeded(true);
        insertAtCursor("=");
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
        fractionMode = false;
        cursorPos = 0;
    }

    // Solves the equation if the expression contains a literal "=" (put
    // there by the EQ button - see insertEquals()), otherwise it's a plain
    // calculation using whatever variables are currently known - e.g. "X+1"
    // evaluates straight to 11 once X is known, no "=" involved.
    function evaluate() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        if (expr.find("=") != null) {
            solveEquation();
            return;
        }
        var parser = new ExprParser(closeUnmatchedParens(expr), 0.0d, variables);
        var result = parser.parse();
        if (parser.error) {
            errorState = true;
            return;
        }
        lastAnswer = result;
        expr = formatNumber(result);
        justEvaluated = true;
        fractionMode = false;
        cursorPos = expr.length();
    }

    // Flips the just-shown "=" result between decimal and a/b fraction
    // form. A second press flips it back - it doesn't affect anything
    // else, so typing after it (or a fresh "=") always starts decimal.
    function toggleFraction() as Void {
        if (errorState || !justEvaluated) {
            return;
        }
        fractionMode = !fractionMode;
        expr = fractionMode ? formatFraction(lastAnswer) : formatNumber(lastAnswer);
        cursorPos = expr.length();
    }

    // Continued-fraction approximation of `v` as a/b, capped at a 4-digit
    // denominator so it stays a short, useful fraction rather than a
    // perfect-but-unreadable one for values that aren't a clean ratio.
    private function formatFraction(v as Double) as String {
        var neg = v < 0.0d;
        var mag = neg ? -v : v;
        var whole = Math.floor(mag).toNumber();
        var frac = mag - whole;
        if (frac < 0.000001d) {
            return formatNumber(v);
        }
        var parts = fractionParts(frac, 9999);
        var num = parts[0] as Number;
        var den = parts[1] as Number;
        var sign = neg ? "-" : "";
        if (whole == 0) {
            return sign + num.toString() + "/" + den.toString();
        }
        return sign + whole.toString() + " " + num.toString() + "/" + den.toString();
    }

    // Standard continued-fraction convergents of x (0 < x < 1): keeps
    // refining num/den until the denominator would exceed maxDen, then
    // stops and returns the last convergent that fit.
    private function fractionParts(x as Double, maxDen as Number) as Array<Number> {
        var hPrev2 = 0; var hPrev1 = 1;
        var kPrev2 = 1; var kPrev1 = 0;
        var num = 0; var den = 1;
        var b = x;
        for (var i = 0; i < 30; i++) {
            var a = Math.floor(b).toNumber();
            var h = a * hPrev1 + hPrev2;
            var k = a * kPrev1 + kPrev2;
            if (k > maxDen) {
                break;
            }
            num = h;
            den = k;
            hPrev2 = hPrev1; hPrev1 = h;
            kPrev2 = kPrev1; kPrev1 = k;
            var rem = b - a;
            if (rem < 0.000001d) {
                break;
            }
            b = 1.0d / rem;
        }
        return [num, den] as Array<Number>;
    }

    // First bare single-letter identifier in s that isn't "e" (the
    // constant) - the equation's unknown. Ignores any prior stored value:
    // building a fresh "LHS=RHS" always (re)solves for it.
    private function findVariableLetter(s as String) as String? {
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
            if (ident.length() == 1 && !(ident.toLower() as String).equals("e")) {
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
    private function solveEquation() as Void {
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
        var letterOrNull = findVariableLetter(lhs);
        if (letterOrNull == null) {
            letterOrNull = findVariableLetter(rhs);
        }
        if (letterOrNull == null) {
            // No unknown on either side - "LHS=RHS" isn't an equation to
            // solve, just two values to compare, so show their difference
            // instead of erroring (0 means they're actually equal).
            var diff = evalDiff("x", lhs, rhs, 0.0d);
            if (diff == null) {
                errorState = true;
                return;
            }
            expr = formatNumber(diff as Double);
            lastAnswer = diff as Double;
            justEvaluated = true;
            cursorPos = expr.length();
            return;
        }
        var letter = letterOrNull as String;

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
        var solved = -b / a;
        expr = letter + "=" + formatNumber(solved);
        lastAnswer = solved;
        // Solving always overwrites: a fresh equation for the same letter
        // (long-press "=" again to build a new one) redefines it freely.
        variables[letter] = solved;
        persistVariables();
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
        var stack = openBracketStack(s);
        var out = s;
        var i = stack.size() - 1;
        while (i >= 0) {
            out = out + closeFor(stack[i]);
            i -= 1;
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

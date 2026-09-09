import Toybox.Lang;
import Toybox.Math;

// Text-expression calculator: button presses build up a formula string
// (so parentheses and arbitrary powers work naturally), evaluated by
// ExprParser on "=".
class CalculatorEngine {

    var expr as String = "";
    var errorState as Boolean = false;
    private var justEvaluated as Boolean = false;

    function initialize() {
    }

    function displayText() as String {
        if (errorState) {
            return "Error";
        }
        return expr.length() == 0 ? "0" : expr;
    }

    function appendDigit(d as String) as Void {
        resetIfNeeded(true);
        expr = expr + d;
    }

    function appendOperator(op as String) as Void {
        resetIfNeeded(false);
        expr = expr + op;
    }

    function appendFunction(name as String) as Void {
        resetIfNeeded(true);
        expr = expr + name + "(";
    }

    function appendConstant(sym as String) as Void {
        resetIfNeeded(true);
        expr = expr + sym;
    }

    function openParen() as Void {
        resetIfNeeded(true);
        expr = expr + "(";
    }

    function closeParen() as Void {
        if (errorState) {
            return;
        }
        expr = expr + ")";
    }

    // Wrap the whole formula so far, e.g. "3+4" -> "(3+4)^2".
    function wrapSquare() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "(" + expr + ")^2";
        justEvaluated = false;
    }

    function wrapCube() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "(" + expr + ")^3";
        justEvaluated = false;
    }

    function wrapInverse() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "1/(" + expr + ")";
        justEvaluated = false;
    }

    function wrapPow10() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "10^(" + expr + ")";
        justEvaluated = false;
    }

    function wrapFactorial() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        expr = "fact(" + expr + ")";
        justEvaluated = false;
    }

    // Raw text insertion for things like the "×10^" scientific-notation
    // shortcut, which don't fit the digit/operator/function/constant shapes.
    function appendRaw(text as String) as Void {
        resetIfNeeded(true);
        expr = expr + text;
    }

    function backspace() as Void {
        if (errorState) {
            clear();
            return;
        }
        if (expr.length() > 0) {
            expr = expr.substring(0, expr.length() - 1) as String;
        }
        justEvaluated = false;
    }

    function clear() as Void {
        expr = "";
        errorState = false;
        justEvaluated = false;
    }

    // "=" does double duty when the formula contains X: the first press
    // inserts "=" (so you can type the right-hand side), the second press
    // solves the equation, e.g. "2X+3" -> "=" -> "2X+3=7" -> "=" -> "X=2".
    function evaluate() as Void {
        if (errorState || expr.length() == 0) {
            return;
        }
        if (expr.find("X") != null || expr.find("x") != null) {
            if (expr.find("=") == null) {
                expr = expr + "=";
                justEvaluated = false;
            } else {
                solveForX();
            }
            return;
        }
        var parser = new ExprParser(closeUnmatchedParens(expr), 0.0d);
        var result = parser.parse();
        if (parser.error) {
            errorState = true;
            return;
        }
        expr = formatNumber(result);
        justEvaluated = true;
    }

    // Linear-equation solver: since f(X) = LHS - RHS is a straight line for
    // any equation built only from +,-,*,/,^ with constant exponents, two
    // sample points fully determine it (f(X) = a*X + b), so X = -b/a. A
    // third sample point catches non-linear formulas instead of silently
    // returning a wrong answer.
    private function solveForX() as Void {
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

        var f0 = evalDiff(lhs, rhs, 0.0d);
        var f1 = evalDiff(lhs, rhs, 1.0d);
        var f2 = evalDiff(lhs, rhs, 2.0d);
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
        expr = "X=" + formatNumber(-b / a);
        justEvaluated = true;
    }

    private function evalDiff(lhs as String, rhs as String, xVal as Double) as Double? {
        var pl = new ExprParser(lhs, xVal);
        var l = pl.parse();
        if (pl.error) {
            return null;
        }
        var pr = new ExprParser(rhs, xVal);
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

    private function formatNumber(v as Double) as String {
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

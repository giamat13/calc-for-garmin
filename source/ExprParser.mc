import Toybox.Lang;
import Toybox.Math;

// Recursive-descent parser/evaluator for calculator formulas: +,-,*,/,^,
// parentheses, unary minus, sin/cos/tan/sqrt/log/ln, and the constants
// pi (as the literal "π") and e.
class ExprParser {

    private var s as String;
    private var len as Number;
    private var pos as Number = 0;
    private var xValue as Double;
    var error as Boolean = false;

    private const E = 2.718281828459045d;

    function initialize(str as String, xVal as Double) {
        s = str;
        len = s.length();
        xValue = xVal;
    }

    function parse() as Double {
        var v = parseExpr();
        if (!error && pos != len) {
            error = true;
        }
        if (error) {
            return 0.0d;
        }
        return v;
    }

    private function peek() as String {
        if (pos >= len) {
            return "";
        }
        return s.substring(pos, pos + 1) as String;
    }

    private function isAlphaCh(c as String) as Boolean {
        if (c.length() != 1) {
            return false;
        }
        var lower = c.toLower() as String;
        return lower.equals("a") || lower.equals("b") || lower.equals("c") || lower.equals("d") ||
               lower.equals("e") || lower.equals("f") || lower.equals("g") || lower.equals("h") ||
               lower.equals("i") || lower.equals("j") || lower.equals("k") || lower.equals("l") ||
               lower.equals("m") || lower.equals("n") || lower.equals("o") || lower.equals("p") ||
               lower.equals("q") || lower.equals("r") || lower.equals("s") || lower.equals("t") ||
               lower.equals("u") || lower.equals("v") || lower.equals("w") || lower.equals("x") ||
               lower.equals("y") || lower.equals("z");
    }

    private function parseExpr() as Double {
        var v = parseTerm();
        while (!error && (peek().equals("+") || peek().equals("-"))) {
            var op = peek();
            pos += 1;
            var rhs = parseTerm();
            v = op.equals("+") ? v + rhs : v - rhs;
        }
        return v;
    }

    private function parseTerm() as Double {
        var v = parseUnary();
        while (!error) {
            var c = peek();
            if (c.equals("*") || c.equals("/")) {
                pos += 1;
                var rhs = parseUnary();
                if (c.equals("/")) {
                    if (rhs == 0.0d) {
                        error = true;
                        return 0.0d;
                    }
                    v = v / rhs;
                } else {
                    v = v * rhs;
                }
            } else if (startsPrimary(c)) {
                // Implicit multiplication: "2X", "2π", "3(1+1)", "2sin(30)".
                v = v * parseUnary();
            } else {
                break;
            }
        }
        return v;
    }

    private function startsPrimary(c as String) as Boolean {
        if (c.equals("")) {
            return false;
        }
        return isDigitLiteral(c) || c.equals(".") || c.equals("(") || c.equals("π") || isAlphaCh(c);
    }

    private function parseUnary() as Double {
        if (peek().equals("-")) {
            pos += 1;
            return -parseUnary();
        }
        if (peek().equals("+")) {
            pos += 1;
            return parseUnary();
        }
        return parsePower();
    }

    private function parsePower() as Double {
        var v = parsePrimary();
        while (!error && peek().equals("%")) {
            v = v * 0.01d;
            pos += 1;
        }
        if (!error && peek().equals("^")) {
            pos += 1;
            var exp = parseUnary();
            v = Math.pow(v, exp) as Double;
        }
        return v;
    }

    private function parsePrimary() as Double {
        var c = peek();
        if (c.equals("")) {
            error = true;
            return 0.0d;
        }
        if (c.equals("(")) {
            pos += 1;
            var v = parseExpr();
            if (!error && peek().equals(")")) {
                pos += 1;
            } else {
                error = true;
            }
            return v;
        }
        if (c.equals("π")) {
            pos += 1;
            return Math.PI.toDouble();
        }
        if (isDigitLiteral(c) || c.equals(".")) {
            return readNumber();
        }
        if (isAlphaCh(c)) {
            var ident = readIdent();
            var lower = ident.toLower() as String;
            if (lower.equals("e")) {
                return E;
            }
            if (lower.equals("x")) {
                return xValue;
            }
            if (!peek().equals("(")) {
                error = true;
                return 0.0d;
            }
            pos += 1;
            var arg = parseExpr();
            if (!error && peek().equals(")")) {
                pos += 1;
            } else {
                error = true;
                return 0.0d;
            }
            return applyFunc(ident, arg);
        }
        error = true;
        return 0.0d;
    }

    private function isDigitLiteral(c as String) as Boolean {
        return c.equals("0") || c.equals("1") || c.equals("2") || c.equals("3") || c.equals("4") ||
               c.equals("5") || c.equals("6") || c.equals("7") || c.equals("8") || c.equals("9");
    }

    private function readNumber() as Double {
        var start = pos;
        while (!peek().equals("") && (isDigitLiteral(peek()) || peek().equals("."))) {
            pos += 1;
        }
        return (s.substring(start, pos) as String).toDouble() as Double;
    }

    private function readIdent() as String {
        var start = pos;
        while (isAlphaCh(peek())) {
            pos += 1;
        }
        return s.substring(start, pos) as String;
    }

    private function applyFunc(name as String, arg as Double) as Double {
        if (name.equals("sin")) {
            return Math.sin(arg * Math.PI / 180.0d) as Double;
        } else if (name.equals("cos")) {
            return Math.cos(arg * Math.PI / 180.0d) as Double;
        } else if (name.equals("tan")) {
            return Math.tan(arg * Math.PI / 180.0d) as Double;
        } else if (name.equals("sqrt")) {
            if (arg < 0.0d) {
                error = true;
                return 0.0d;
            }
            return Math.sqrt(arg) as Double;
        } else if (name.equals("log")) {
            if (arg <= 0.0d) {
                error = true;
                return 0.0d;
            }
            return Math.log(arg, 10.0d) as Double;
        } else if (name.equals("ln")) {
            if (arg <= 0.0d) {
                error = true;
                return 0.0d;
            }
            return Math.log(arg, E) as Double;
        }
        error = true;
        return 0.0d;
    }
}

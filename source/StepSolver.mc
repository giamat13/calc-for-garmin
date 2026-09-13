import Toybox.Lang;
import Toybox.Math;

// One node of a parsed expression, tagged with its source span [start,end)
// in the original string. A "leaf" is a plain number (literal, constant,
// variable, or a value already fully resolved by sign/percent/brackets
// wrapping a leaf) - anything else (a binary op or function call) is a
// pending operation that computeSolutionSteps() can collapse one at a time.
class StepNode {
    var kind as String; // "leaf", "bin", or "func"
    var start as Number;
    var end as Number;
    var value as Double;
    var left as StepNode?;
    var right as StepNode?;

    function initialize(k as String, st as Number, en as Number, v as Double, l as StepNode?, r as StepNode?) {
        kind = k;
        start = st;
        end = en;
        value = v;
        left = l;
        right = r;
    }
}

// Returns the first (deepest, then highest-precedence, then left-most) node
// still awaiting an operation - i.e. the next step of the solution - or
// null if the whole tree is already a single leaf.
function findFirstStepNode(n as StepNode) as StepNode? {
    if (n.kind.equals("leaf")) {
        return null;
    }
    if (n.left != null) {
        var fromLeft = findFirstStepNode(n.left as StepNode);
        if (fromLeft != null) {
            return fromLeft;
        }
    }
    if (n.right != null) {
        var fromRight = findFirstStepNode(n.right as StepNode);
        if (fromRight != null) {
            return fromRight;
        }
    }
    return n;
}

// Same grammar/semantics as ExprParser, but building a span-tagged tree
// instead of folding straight to a Double, so the engine can splice just
// one sub-expression's result back into the displayed formula at a time.
class StepSolver {

    private var s as String;
    private var len as Number;
    private var pos as Number = 0;
    private var xValue as Double;
    private var variables as Dictionary<String, Double>;
    var error as Boolean = false;

    private const E = 2.718281828459045d;

    function initialize(str as String, xVal as Double, vars as Dictionary<String, Double>) {
        s = str;
        len = s.length();
        xValue = xVal;
        variables = vars;
    }

    // Returns the root node, or null on a parse error.
    function buildTree() as StepNode? {
        var node = parseExprNode();
        if (!error && pos != len) {
            error = true;
        }
        if (error) {
            return null;
        }
        return node;
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

    private function isDigitLiteral(c as String) as Boolean {
        return c.equals("0") || c.equals("1") || c.equals("2") || c.equals("3") || c.equals("4") ||
               c.equals("5") || c.equals("6") || c.equals("7") || c.equals("8") || c.equals("9");
    }

    private function startsPrimary(c as String) as Boolean {
        if (c.equals("")) {
            return false;
        }
        return isDigitLiteral(c) || c.equals(".") || c.equals("(") || c.equals("[") || c.equals("{") ||
            c.equals("π") || isAlphaCh(c);
    }

    private function matchKeyword(kw as String) as Boolean {
        var kwLen = kw.length();
        if (pos + kwLen > len) {
            return false;
        }
        if (!(s.substring(pos, pos + kwLen) as String).equals(kw)) {
            return false;
        }
        if (pos + kwLen < len && isAlphaCh(s.substring(pos + kwLen, pos + kwLen + 1) as String)) {
            return false;
        }
        return true;
    }

    private function leaf(st as Number, en as Number, v as Double) as StepNode {
        return new StepNode("leaf", st, en, v, null, null);
    }

    private function parseExprNode() as StepNode {
        var v = parseTermNode();
        while (!error && (peek().equals("+") || peek().equals("-"))) {
            var op = peek();
            var st = v.start;
            pos += 1;
            var rhs = parseTermNode();
            var value = op.equals("+") ? v.value + rhs.value : v.value - rhs.value;
            v = new StepNode("bin", st, rhs.end, value, v, rhs);
        }
        return v;
    }

    private function parseTermNode() as StepNode {
        var v = parseUnaryNode();
        while (!error) {
            var c = peek();
            var st = v.start;
            if (c.equals("*") || c.equals("/")) {
                pos += 1;
                var rhs = parseUnaryNode();
                if (c.equals("/")) {
                    if (rhs.value == 0.0d) {
                        error = true;
                        return v;
                    }
                    v = new StepNode("bin", st, rhs.end, v.value / rhs.value, v, rhs);
                } else {
                    v = new StepNode("bin", st, rhs.end, v.value * rhs.value, v, rhs);
                }
            } else if (matchKeyword("mod")) {
                pos += 3;
                var rhs2 = parseUnaryNode();
                if (rhs2.value == 0.0d) {
                    error = true;
                    return v;
                }
                var modVal = v.value - Math.floor(v.value / rhs2.value) * rhs2.value;
                v = new StepNode("bin", st, rhs2.end, modVal, v, rhs2);
            } else if (startsPrimary(c)) {
                // Implicit multiplication: "2X", "2π", "3(1+1)", "2sin(30)".
                var rhs3 = parseUnaryNode();
                v = new StepNode("bin", st, rhs3.end, v.value * rhs3.value, v, rhs3);
            } else {
                break;
            }
        }
        return v;
    }

    private function parseUnaryNode() as StepNode {
        if (peek().equals("-")) {
            var st = pos;
            pos += 1;
            var inner = parseUnaryNode();
            if (inner.kind.equals("leaf")) {
                return leaf(st, inner.end, -inner.value);
            }
            return new StepNode("bin", st, inner.end, 0.0d, null, inner);
        }
        if (peek().equals("+")) {
            pos += 1;
            return parseUnaryNode();
        }
        return parsePowerNode();
    }

    private function parsePowerNode() as StepNode {
        var v = parsePrimaryNode();
        while (!error && peek().equals("%")) {
            var st = v.start;
            var en = pos + 1;
            pos += 1;
            if (v.kind.equals("leaf")) {
                v = leaf(st, en, v.value * 0.01d);
            } else {
                v = new StepNode("bin", st, en, 0.0d, null, v);
            }
        }
        if (!error && peek().equals("^")) {
            var st2 = v.start;
            pos += 1;
            var exp = parseUnaryNode();
            v = new StepNode("bin", st2, exp.end, Math.pow(v.value, exp.value) as Double, v, exp);
        }
        return v;
    }

    private function parsePrimaryNode() as StepNode {
        var c = peek();
        if (c.equals("")) {
            error = true;
            return leaf(pos, pos, 0.0d);
        }
        if (c.equals("(") || c.equals("[") || c.equals("{")) {
            var closeCh = c.equals("[") ? "]" : (c.equals("{") ? "}" : ")");
            var openPos = pos;
            pos += 1;
            var inner = parseExprNode();
            if (!error && peek().equals(closeCh)) {
                pos += 1;
            } else {
                error = true;
                return inner;
            }
            // Pure grouping isn't an operation - once the content is a
            // leaf, the brackets are just along for the ride, so swallow
            // them too. Otherwise leave the span as the bare inner content
            // so it can still be collapsed on its own, brackets and all
            // remaining in the text until it does.
            if (inner.kind.equals("leaf")) {
                return leaf(openPos, pos, inner.value);
            }
            return inner;
        }
        if (c.equals("π")) {
            var piStart = pos;
            pos += 1;
            return leaf(piStart, pos, Math.PI.toDouble());
        }
        if (isDigitLiteral(c) || c.equals(".")) {
            return readNumberNode();
        }
        if (isAlphaCh(c)) {
            var identStart = pos;
            var ident = readIdent();
            var lower = ident.toLower() as String;
            if (lower.equals("e")) {
                return leaf(identStart, pos, E);
            }
            if (variables.hasKey(ident)) {
                return leaf(identStart, pos, variables[ident] as Double);
            }
            if (lower.equals("x")) {
                return leaf(identStart, pos, xValue);
            }
            if (!peek().equals("(")) {
                error = true;
                return leaf(identStart, pos, 0.0d);
            }
            pos += 1;
            var arg = parseExprNode();
            if (!error && peek().equals(")")) {
                pos += 1;
            } else {
                error = true;
                return arg;
            }
            if (!arg.kind.equals("leaf")) {
                // Argument still has its own pending operation(s) - resolve
                // those before this function call becomes collapsible.
                return new StepNode("func", identStart, pos, 0.0d, null, arg);
            }
            var value = applyFunc(ident, arg.value);
            return new StepNode("func", identStart, pos, value, null, arg);
        }
        error = true;
        return leaf(pos, pos, 0.0d);
    }

    private function readNumberNode() as StepNode {
        var start = pos;
        while (!peek().equals("") && (isDigitLiteral(peek()) || peek().equals("."))) {
            pos += 1;
        }
        var v = (s.substring(start, pos) as String).toDouble() as Double;
        if (peek().equals(":")) {
            pos += 1;
            var secStart = pos;
            while (isDigitLiteral(peek())) {
                pos += 1;
            }
            if (pos == secStart) {
                error = true;
                return leaf(start, pos, 0.0d);
            }
            v = v + ((s.substring(secStart, pos) as String).toDouble() as Double) / 60.0d;
        }
        return leaf(start, pos, v);
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
        } else if (name.equals("asin")) {
            if (arg < -1.0d || arg > 1.0d) {
                error = true;
                return 0.0d;
            }
            return (Math.asin(arg) as Double) * 180.0d / Math.PI;
        } else if (name.equals("acos")) {
            if (arg < -1.0d || arg > 1.0d) {
                error = true;
                return 0.0d;
            }
            return (Math.acos(arg) as Double) * 180.0d / Math.PI;
        } else if (name.equals("atan")) {
            return (Math.atan(arg) as Double) * 180.0d / Math.PI;
        } else if (name.equals("cbrt")) {
            return arg < 0.0d ? -(Math.pow(-arg, 1.0d / 3.0d) as Double) : (Math.pow(arg, 1.0d / 3.0d) as Double);
        } else if (name.equals("abs")) {
            return arg < 0.0d ? -arg : arg;
        } else if (name.equals("floor")) {
            return Math.floor(arg) as Double;
        } else if (name.equals("ceil")) {
            return Math.ceil(arg) as Double;
        } else if (name.equals("fact")) {
            return factorial(arg);
        }
        error = true;
        return 0.0d;
    }

    private function factorial(arg as Double) as Double {
        var rounded = Math.round(arg) as Double;
        var diff = arg - rounded;
        if (diff < 0.0d) {
            diff = -diff;
        }
        if (diff > 0.0000001d || rounded < 0.0d || rounded > 170.0d) {
            error = true;
            return 0.0d;
        }
        var n = rounded.toNumber();
        var result = 1.0d;
        for (var i = 2; i <= n; i++) {
            result = result * i;
        }
        return result;
    }
}

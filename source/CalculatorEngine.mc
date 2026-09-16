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

    // Every function name appendFunction() can insert as "name(" - used by
    // backspace() to delete a freshly-opened call in one press instead of
    // walking it out letter by letter. ("fact" has no button of its own -
    // wrapFactorial() appends "!" postfix instead - but ExprParser accepts
    // "fact(" too, so it's included for consistency.)
    private const FUNCTION_NAMES = [
        "sin", "cos", "tan", "sqrt", "log", "ln", "asin", "acos", "atan", "cbrt", "abs", "floor", "ceil", "fact"
    ] as Array<String>;

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

    // Inserts a single-letter variable (or "e"/"π") at the cursor. If the
    // character right before the cursor is also a bare letter, "AB" would
    // otherwise concatenate into ExprParser's identifier reader as one
    // 2+-letter run - which, if it happened to spell a real function name
    // (e.g. tapping "S" then "I" then "N"), would silently parse as that
    // function instead of three multiplied variables. An explicit "*"
    // keeps every letter unambiguous, so all of them (not just a
    // non-function-prefix subset) are safe to offer as variables.
    function appendConstant(sym as String) as Void {
        resetIfNeeded(true);
        if (cursorPos > 0 && sym.length() == 1 && isAsciiLetter(sym) &&
                isAsciiLetter(expr.substring(cursorPos - 1, cursorPos) as String)) {
            insertAtCursor("*" + sym);
        } else {
            insertAtCursor(sym);
        }
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
            var cut = functionCallLengthBeforeCursor();
            var n = cut > 0 ? cut : 1;
            expr = (expr.substring(0, cursorPos - n) as String) + (expr.substring(cursorPos, expr.length()) as String);
            cursorPos -= n;
        }
        justEvaluated = false;
    }

    // If the cursor sits right after "name(" for a known function - i.e.
    // the call was just opened and nothing's been typed inside it yet -
    // one backspace should remove the whole "name(" instead of peeling it
    // one character at a time (typing "log(" then changing your mind
    // shouldn't take 4 presses). Returns the number of characters to
    // delete, or 0 if the cursor isn't right after such an opening.
    private function functionCallLengthBeforeCursor() as Number {
        if (cursorPos < 2 || !(expr.substring(cursorPos - 1, cursorPos) as String).equals("(")) {
            return 0;
        }
        for (var i = 0; i < FUNCTION_NAMES.size(); i++) {
            var name = FUNCTION_NAMES[i] as String;
            var nameLen = name.length();
            var start = cursorPos - 1 - nameLen;
            if (start < 0) {
                continue;
            }
            if (!(expr.substring(start, cursorPos - 1) as String).equals(name)) {
                continue;
            }
            // Don't swallow a longer identifier this name is just a
            // suffix of - e.g. matching "sin" inside "asin(" - the actual
            // "asin" entry handles that case on its own.
            if (start > 0 && isAsciiLetter(expr.substring(start - 1, start) as String)) {
                continue;
            }
            return nameLen + 1;
        }
        return 0;
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

    // Replays the order-of-operations walk for an already-typed expression
    // (as stored in history), returning every intermediate stage from the
    // raw input through to the final result - e.g. "2+3*4" ->
    // ["2+3*4", "2+12", "14"]. Used by the history detail screen so a past
    // calculation can be shown solved one step at a time, each with its own
    // paste button. Pure function of its argument - doesn't touch this
    // engine's own expr/cursor/errorState.
    //
    // `knownAnswer` is the result already recorded in history for this
    // expression (from the original evaluate() call). The symbolic walk
    // below re-derives the same thing step by step, but on some devices it
    // can bail out early (e.g. a StepSolver quirk on a particular
    // expression shape) - when that happens we'd otherwise show just the
    // raw expression with no answer at all. Since the real answer is
    // already known, always make sure it ends up as the last step even if
    // the walk itself couldn't get there.
    (:exclude_oldwidget)
    function computeSolutionSteps(startExpr as String, knownAnswer as String?) as Array<String> {
        var steps = [] as Array<String>;
        if (startExpr.length() == 0) {
            return steps;
        }
        steps.add(startExpr);
        var eqIdxOrNull = startExpr.find("=");
        if (eqIdxOrNull != null) {
            // Equation-solving on top of an order-of-operations walk: first
            // collapse whichever side is pure arithmetic (no unknown) one
            // step at a time - e.g. "5+5*3=X" -> "5+15=X" -> "20=X" - then
            // show the optional "collect terms" step (aX=C) when it adds
            // real information, then the solved form.
            var eqIdx = eqIdxOrNull as Number;
            var lhsPart = closeUnmatchedParens(startExpr.substring(0, eqIdx) as String);
            var rhsPart = closeUnmatchedParens(startExpr.substring(eqIdx + 1, startExpr.length()) as String);
            var letter = findVariableLetter(lhsPart);
            if (letter == null) {
                letter = findVariableLetter(rhsPart);
            }
            if (letter != null) {
                walkEquationConstants(steps, letter as String, lhsPart, rhsPart);
            }
            var collect = equationCollectStep(startExpr);
            if (collect != null && !(collect as String).equals(startExpr) && !(collect as String).equals(steps[steps.size() - 1])) {
                steps.add(collect as String);
            }
            var solved = solveEquationForDisplay(startExpr);
            if (solved != null && !(solved as String).equals(steps[steps.size() - 1])) {
                steps.add(solved as String);
            }
            return ensureFinalAnswer(steps, knownAnswer);
        }
        var current = startExpr;
        // One collapse per iteration, same order-of-operations walk -
        // capped so a pathological/unexpected input can't loop forever.
        for (var guard = 0; guard < 64; guard++) {
            var solver = new StepSolver(closeUnmatchedParens(current), 0.0d, variables);
            var root = solver.buildTree();
            if (solver.error || root == null) {
                return ensureFinalAnswer(steps, knownAnswer);
            }
            var node = findFirstStepNode(root as StepNode);
            if (node == null) {
                break;
            }
            current = (current.substring(0, node.start) as String) + formatNumber(node.value) +
                (current.substring(node.end, current.length()) as String);
            steps.add(current);
        }
        return ensureFinalAnswer(steps, knownAnswer);
    }

    // Order-of-operations walk for both sides of an equation, but constants
    // only - any subtree that has the unknown letter inside it is left
    // untouched, so a mixed side like "5-4+X" collapses to "1+X" instead of
    // jumping straight past it. Each iteration collapses one pure-constant
    // node (lhs first, then rhs) and re-glues both sides with "=" so every
    // step still reads as a full equation (e.g. "5-4+X=30" -> "1+X=30").
    // Appends steps in place; stops once neither side has a collapsible
    // constant part left.
    (:exclude_oldwidget)
    private function walkEquationConstants(steps as Array<String>, letter as String, lhsIn as String, rhsIn as String) as Void {
        var lhs = lhsIn;
        var rhs = rhsIn;
        for (var guard = 0; guard < 64; guard++) {
            var collapsedLhs = collapseOnePureNode(lhs, letter);
            if (collapsedLhs != null) {
                lhs = collapsedLhs as String;
                steps.add(lhs + "=" + rhs);
                continue;
            }
            var collapsedRhs = collapseOnePureNode(rhs, letter);
            if (collapsedRhs != null) {
                rhs = collapsedRhs as String;
                steps.add(lhs + "=" + rhs);
                continue;
            }
            break;
        }
    }

    // Collapses the first (deepest, leftmost) constants-only node in
    // `sideExpr`, skipping any subtree that contains the unknown letter -
    // those get resolved later by equationCollectStep()/
    // solveEquationForDisplay() instead. Returns null when the side fails
    // to parse or has nothing left to collapse.
    (:exclude_oldwidget)
    private function collapseOnePureNode(sideExpr as String, letter as String) as String? {
        if (sideExpr.length() == 0) {
            return null;
        }
        var solver = new StepSolver(closeUnmatchedParens(sideExpr), 0.0d, variables);
        var root = solver.buildTree();
        if (solver.error || root == null) {
            return null;
        }
        var node = findFirstPureStepNode(root as StepNode, letter, sideExpr);
        if (node == null) {
            return null;
        }
        return (sideExpr.substring(0, node.start) as String) + formatNumber(node.value) +
            (sideExpr.substring(node.end, sideExpr.length()) as String);
    }

    // Like findFirstStepNode(), but won't return a node whose span contains
    // the unknown letter - it recurses past such nodes into their children
    // instead, looking for a pure-constant pocket to collapse first (e.g.
    // in "5-4+X", it steps past the root and into "5-4").
    (:exclude_oldwidget)
    private function findFirstPureStepNode(n as StepNode, letter as String, text as String) as StepNode? {
        var span = text.substring(n.start, n.end) as String;
        if (!containsUnknownToken(span, letter)) {
            if (n.kind.equals("leaf")) {
                return null;
            }
            return findFirstStepNode(n);
        }
        if (n.left != null) {
            var fromLeft = findFirstPureStepNode(n.left as StepNode, letter, text);
            if (fromLeft != null) {
                return fromLeft;
            }
        }
        if (n.right != null) {
            var fromRight = findFirstPureStepNode(n.right as StepNode, letter, text);
            if (fromRight != null) {
                return fromRight;
            }
        }
        return null;
    }

    // True if `letter` occurs in `text` as its own single-character
    // identifier (not as part of a longer word) - used to tell a
    // constants-only subexpression apart from one that still has the
    // unknown mixed into it.
    (:exclude_oldwidget)
    private function containsUnknownToken(text as String, letter as String) as Boolean {
        var i = 0;
        while (i < text.length()) {
            var c = text.substring(i, i + 1) as String;
            if (isAsciiLetter(c)) {
                var start = i;
                while (i < text.length() && isAsciiLetter(text.substring(i, i + 1) as String)) {
                    i += 1;
                }
                var ident = text.substring(start, i) as String;
                if (ident.length() == 1 && ident.equals(letter)) {
                    return true;
                }
            } else {
                i += 1;
            }
        }
        return false;
    }

    // Low-memory fallback for watches too small to fit StepSolver (see the
    // pool comment at the top of SeedConfig.mc for that device list) - no
    // order-of-operations walk, just the typed expression (and, for an
    // equation, its solved form) plus the already-known final answer. The
    // history detail screen still works, it just skips the intermediate
    // stages.
    (:oldwidget_only)
    function computeSolutionSteps(startExpr as String, knownAnswer as String?) as Array<String> {
        var steps = [] as Array<String>;
        if (startExpr.length() == 0) {
            return steps;
        }
        steps.add(startExpr);
        if (startExpr.find("=") != null) {
            var solved = solveEquationForDisplay(startExpr);
            if (solved != null) {
                steps.add(solved as String);
            }
        }
        return ensureFinalAnswer(steps, knownAnswer);
    }

    // Appends `knownAnswer` to `steps` unless it's empty/null or already the
    // last entry - see computeSolutionSteps().
    private function ensureFinalAnswer(steps as Array<String>, knownAnswer as String?) as Array<String> {
        if (knownAnswer == null || (knownAnswer as String).length() == 0) {
            return steps;
        }
        if (steps.size() > 0 && (steps[steps.size() - 1] as String).equals(knownAnswer as String)) {
            return steps;
        }
        steps.add(knownAnswer as String);
        return steps;
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
    // third sample point catches non-linear formulas so they can fall back
    // to solveNumeric() (a reciprocal like "3/x", or the unknown appearing
    // on both sides in a way that doesn't cancel to affine) instead of
    // silently returning a wrong answer.
    private function solveEquation() as Void {
        var resultOrNull = solveEquationForDisplay(expr);
        if (resultOrNull == null) {
            errorState = true;
            return;
        }
        var result = resultOrNull as String;
        var eqIdxOrNull = result.find("=");
        if (eqIdxOrNull != null) {
            var letter = result.substring(0, eqIdxOrNull as Number) as String;
            var value = (result.substring((eqIdxOrNull as Number) + 1, result.length()) as String).toDouble() as Double;
            // Solving always overwrites: a fresh equation for the same
            // letter (long-press "=" again to build a new one) redefines it
            // freely.
            variables[letter] = value;
            persistVariables();
            lastAnswer = value;
        } else {
            lastAnswer = result.toDouble() as Double;
        }
        expr = result;
        justEvaluated = true;
        cursorPos = expr.length();
    }

    // The pure math behind solveEquation() - "letter=value" for an unknown,
    // or a plain number (the LHS-RHS difference) when both sides are
    // already known - or null if unsolvable. Never mutates `variables` or
    // Storage, so computeSolutionSteps() can reuse it just to show what an
    // already-recorded equation solved to, without redefining anything.
    private function solveEquationForDisplay(equationExpr as String) as String? {
        var eqIdxOrNull = equationExpr.find("=");
        if (eqIdxOrNull == null) {
            return null;
        }
        var eqIdx = eqIdxOrNull as Number;
        var lhs = closeUnmatchedParens(equationExpr.substring(0, eqIdx) as String);
        var rhs = closeUnmatchedParens(equationExpr.substring(eqIdx + 1, equationExpr.length()) as String);
        if (lhs.length() == 0 || rhs.length() == 0) {
            return null;
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
            return diff == null ? null : formatNumber(diff as Double);
        }
        var letter = letterOrNull as String;

        var affine = solveAffine(letter, lhs, rhs);
        if (affine != null) {
            return letter + "=" + formatNumber((affine as Array<Double>)[0]);
        }
        var numeric = solveNumeric(letter, lhs, rhs);
        if (numeric == null) {
            return null;
        }
        return letter + "=" + formatNumber(numeric as Double);
    }

    // "aX=C" collect-terms form shown as a step before the final "X=value"
    // - only when the equation is affine in the unknown and there's
    // actually a coefficient/constant to isolate; a==1 with C already equal
    // to the solved value would just duplicate the final step, so that case
    // returns null and computeSolutionSteps() shows the plain 2-step form.
    private function equationCollectStep(equationExpr as String) as String? {
        var eqIdxOrNull = equationExpr.find("=");
        if (eqIdxOrNull == null) {
            return null;
        }
        var eqIdx = eqIdxOrNull as Number;
        var lhs = closeUnmatchedParens(equationExpr.substring(0, eqIdx) as String);
        var rhs = closeUnmatchedParens(equationExpr.substring(eqIdx + 1, equationExpr.length()) as String);
        if (lhs.length() == 0 || rhs.length() == 0) {
            return null;
        }
        var letterOrNull = findVariableLetter(lhs);
        if (letterOrNull == null) {
            letterOrNull = findVariableLetter(rhs);
        }
        if (letterOrNull == null) {
            return null;
        }
        var letter = letterOrNull as String;
        var affine = solveAffine(letter, lhs, rhs);
        if (affine == null) {
            return null;
        }
        var a = (affine as Array<Double>)[1];
        var b = (affine as Array<Double>)[2];
        if (a == 1.0d) {
            return null;
        }
        var coeff = a == -1.0d ? "-" + letter : formatNumber(a) + letter;
        return coeff + "=" + formatNumber(-b);
    }

    // Fast, exact path: tries a few different trial triples (not just
    // 0,1,2) so a singularity at one candidate point - e.g. "3/x" at x=0 -
    // doesn't block the fit. Returns [root, a, b] where f(letter) = a*letter
    // + b, or null if no triple samples cleanly or the relationship
    // genuinely isn't affine in `letter`; the caller then falls back to
    // solveNumeric(). The a/b coefficients let computeSolutionSteps() show
    // a "collect terms" step (aX=C) before the final solved value.
    private function solveAffine(letter as String, lhs as String, rhs as String) as Array<Double>? {
        var solved = solveAffineTriple(letter, lhs, rhs, 0.0d, 1.0d, 2.0d);
        if (solved != null) {
            return solved;
        }
        solved = solveAffineTriple(letter, lhs, rhs, 1.0d, 2.0d, 3.0d);
        if (solved != null) {
            return solved;
        }
        solved = solveAffineTriple(letter, lhs, rhs, 2.0d, 3.0d, 5.0d);
        if (solved != null) {
            return solved;
        }
        return solveAffineTriple(letter, lhs, rhs, -1.0d, 1.0d, 3.0d);
    }

    private function solveAffineTriple(letter as String, lhs as String, rhs as String, t0 as Double, t1 as Double, t2 as Double) as Array<Double>? {
        var f0 = evalDiff(letter, lhs, rhs, t0);
        var f1 = evalDiff(letter, lhs, rhs, t1);
        var f2 = evalDiff(letter, lhs, rhs, t2);
        if (f0 == null || f1 == null || f2 == null) {
            return null;
        }
        var b = f0 as Double;
        var a = ((f1 as Double) - b) / (t1 - t0);
        if (a == 0.0d) {
            return null;
        }
        var predicted = a * (t2 - t0) + b;
        var residual = (f2 as Double) - predicted;
        if (residual < 0.0d) {
            residual = -residual;
        }
        if (residual > 0.0001d) {
            return null;
        }
        // f(letter) = a*(letter - t0) + b = a*letter + (b - a*t0)
        var bAtZero = b - a * t0;
        var root = -bAtZero / a;
        return [root, a, bAtZero] as Array<Double>;
    }

    // General fallback for a relationship that isn't affine in `letter` -
    // a reciprocal like "3/x", or the unknown on both sides in a way that
    // doesn't cancel down to a line. Scans a wide, geometrically-spaced
    // range of trial values (skipping any that error, e.g. a division by
    // zero exactly at that value) for a sign change in
    // f(letter) = LHS - RHS, then bisects down to the root. A sign change
    // can also happen at a POLE instead of a root - e.g. "3/x" flips from
    // +infinity to -infinity across x=0, which looks like a crossing but
    // isn't one - so every bracket is verified (the true root drives
    // f(letter) itself near zero; a pole doesn't) before being accepted,
    // and rejected brackets just keep the scan going. Returns null if no
    // genuine root turns up anywhere in the scanned range - same "can't
    // solve this" outcome solveAffine would have given, just reached a
    // different way.
    private function solveNumeric(letter as String, lhs as String, rhs as String) as Double? {
        var mags = [] as Array<Double>;
        var mag = 0.0001d;
        for (var i = 0; i < 130; i++) {
            mags.add(mag);
            mag = mag * 1.2d;
        }
        var points = [] as Array<Double>;
        for (var i = mags.size() - 1; i >= 0; i--) {
            points.add(-(mags[i] as Double));
        }
        for (var i = 0; i < mags.size(); i++) {
            points.add(mags[i] as Double);
        }

        var prevV = points[0] as Double;
        var prevF = evalDiff(letter, lhs, rhs, prevV);
        for (var i = 1; i < points.size(); i++) {
            var v = points[i] as Double;
            var f = evalDiff(letter, lhs, rhs, v);
            if (f != null && (f as Double) == 0.0d) {
                return v;
            }
            if (prevF != null && f != null && ((prevF as Double) < 0.0d) != ((f as Double) < 0.0d)) {
                var candidate = bisectRoot(letter, lhs, rhs, prevV, v);
                if (candidate != null) {
                    var check = evalDiff(letter, lhs, rhs, candidate as Double);
                    if (check != null) {
                        var mag2 = check as Double;
                        if (mag2 < 0.0d) {
                            mag2 = -mag2;
                        }
                        if (mag2 < 0.0001d) {
                            return candidate;
                        }
                    }
                }
                // The bracket straddled a pole, not a root - keep scanning
                // past it instead of reporting a bogus near-zero answer.
            }
            prevV = v;
            prevF = f;
        }
        return null;
    }

    // Narrows a bracket known to contain a sign change of
    // f(letter) = LHS - RHS down to the root. 60 halvings converge well
    // past the precision formatNumber() displays even for the widest
    // brackets solveNumeric() can hand it.
    private function bisectRoot(letter as String, lhs as String, rhs as String, loIn as Double, hiIn as Double) as Double? {
        var lo = loIn;
        var hi = hiIn;
        var flo = evalDiff(letter, lhs, rhs, lo);
        if (flo == null) {
            return null;
        }
        for (var i = 0; i < 60; i++) {
            var mid = (lo + hi) / 2.0d;
            var fmid = evalDiff(letter, lhs, rhs, mid);
            if (fmid == null) {
                // Straddled an undefined point (e.g. a denominator hitting
                // zero exactly at the midpoint) - nudge and retry once
                // rather than giving up the whole bracket.
                mid = mid + (hi - lo) * 0.0001d;
                fmid = evalDiff(letter, lhs, rhs, mid);
                if (fmid == null) {
                    return (lo + hi) / 2.0d;
                }
            }
            if ((fmid as Double) == 0.0d) {
                return mid;
            }
            if (((flo as Double) < 0.0d) != ((fmid as Double) < 0.0d)) {
                hi = mid;
            } else {
                lo = mid;
                flo = fmid;
            }
        }
        return (lo + hi) / 2.0d;
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

import Toybox.Test;
import Toybox.Lang;

(:test)
function testBasicArithmetic(logger as Test.Logger) as Boolean {
    var p = new ExprParser("2+3*4", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 14.0d, logger);
}

(:test)
function testParens(logger as Test.Logger) as Boolean {
    var p = new ExprParser("(2+3)*4", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 20.0d, logger);
}

(:test)
function testPower(logger as Test.Logger) as Boolean {
    var p = new ExprParser("2^3^2", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    // right-associative: 2^(3^2) = 2^9 = 512
    return !p.error && near(v, 512.0d, logger);
}

(:test)
function testFunctionAndConst(logger as Test.Logger) as Boolean {
    var p = new ExprParser("sqrt(9)+π", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 3.0d + 3.14159265d, logger);
}

(:test)
function testUnaryMinus(logger as Test.Logger) as Boolean {
    var p = new ExprParser("-2^2", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    // unary minus applied after power of the primary: -(2^2) = -4
    return !p.error && near(v, -4.0d, logger);
}

(:test)
function testDivideByZeroErrors(logger as Test.Logger) as Boolean {
    var p = new ExprParser("5/0", 0.0d, {} as Dictionary<String, Double>);
    p.parse();
    if (!p.error) {
        logger.debug("expected error on divide by zero");
        return false;
    }
    return true;
}

(:test)
function testPercent(logger as Test.Logger) as Boolean {
    var p = new ExprParser("50%", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 0.5d, logger);
}

(:test)
function testVariableX(logger as Test.Logger) as Boolean {
    var p = new ExprParser("2*X+1", 5.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 11.0d, logger);
}

// The EQ button inserts the "=" sign itself (insertEquals()); a short
// press on "=" (evaluate()) then solves,
// since the expression now contains "=".
(:test)
function testEquationEngine(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    // Variables persist across app runs now, so start from a clean slate
    // regardless of whatever an earlier test run left in Storage.
    e.clearVariables();
    e.appendDigit("2");
    e.appendConstant("X");
    e.appendOperator("+");
    e.appendDigit("3");
    e.insertEquals();
    if (!e.expr.equals("2X+3=")) {
        logger.debug("expected '2X+3=' got '" + e.expr + "'");
        return false;
    }
    e.appendDigit("7");
    e.evaluate();
    if (e.errorState) {
        logger.debug("solver errored unexpectedly");
        return false;
    }
    if (!e.expr.equals("X=2")) {
        logger.debug("expected 'X=2' got '" + e.expr + "'");
        return false;
    }
    return true;
}

(:test)
function testEquationWithParens(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    // 3*(X-2)=9  ->  X=5
    e.appendDigit("3");
    e.appendOperator("*");
    e.openParen();
    e.appendConstant("X");
    e.appendOperator("-");
    e.appendDigit("2");
    e.closeParen();
    e.insertEquals();
    e.appendDigit("9");
    e.evaluate();
    return !e.errorState && e.expr.equals("X=5");
}

// A known variable stays a plain value ("X+1" -> 11, no "=" needed) but can
// always be redefined: just build a fresh equation with EQ + "="
// again, no separate "forget X" step required.
(:test)
function testEquationCanRedefineAKnownVariable(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendConstant("X");
    e.appendOperator("+");
    e.appendDigit("3");
    e.insertEquals();
    e.appendDigit("7");
    e.evaluate();
    if (!e.expr.equals("X=4")) {
        logger.debug("expected 'X=4' got '" + e.expr + "'");
        return false;
    }
    e.clear();
    e.appendConstant("X");
    e.appendOperator("+");
    e.appendDigit("1");
    e.evaluate();
    if (!e.expr.equals("5")) {
        logger.debug("expected 'X+1' with X=4 to evaluate to '5', got '" + e.expr + "'");
        return false;
    }
    e.clear();
    e.appendDigit("2");
    e.appendConstant("X");
    e.appendOperator("+");
    e.appendDigit("4");
    e.insertEquals();
    e.appendDigit("1");
    e.appendDigit("0");
    e.evaluate();
    if (!e.expr.equals("X=3")) {
        logger.debug("expected 'X=3' got '" + e.expr + "'");
        return false;
    }
    return true;
}

// Solving isn't hardcoded to X any more - any bare single letter works:
// "2Y+3=7" -> "Y=2".
(:test)
function testEquationSolvesForY(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("2");
    e.appendConstant("Y");
    e.appendOperator("+");
    e.appendDigit("3");
    e.insertEquals();
    e.appendDigit("7");
    e.evaluate();
    if (!e.expr.equals("Y=2")) {
        logger.debug("expected 'Y=2' got '" + e.expr + "'");
        return false;
    }
    return true;
}

// Ans holds the last plain "=" result and can be dropped into a new formula.
(:test)
function testAnsInsertsLastAnswer(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.appendDigit("2");
    e.appendOperator("+");
    e.appendDigit("3");
    e.evaluate();
    if (!e.expr.equals("5")) {
        logger.debug("expected '5' got '" + e.expr + "'");
        return false;
    }
    e.insertAns();
    e.appendOperator("*");
    e.appendDigit("2");
    e.evaluate();
    if (!e.expr.equals("10")) {
        logger.debug("expected Ans(5)*2 = '10' got '" + e.expr + "'");
        return false;
    }
    return true;
}

// Once a letter is STO'd, it's a given value, not something to solve for -
// "A+3=8" with A already stored as 2 should just check 2+3==8 (false), not
// try to re-solve for A.
(:test)
function testStoredVariableIsNotTreatedAsUnknown(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("2");
    e.storeVar("A");
    e.clear();
    e.appendConstant("A");
    e.appendOperator("+");
    e.appendDigit("3");
    e.evaluate();
    if (!e.expr.equals("5")) {
        logger.debug("expected 'A+3' with A=2 to evaluate to '5', got '" + e.expr + "'");
        return false;
    }
    return true;
}

// Backspacing right after a freshly-opened function call ("1+log(" with
// nothing typed inside yet) should remove the whole "log(" in one press,
// not walk it out letter by letter.
(:test)
function testBackspaceRemovesWholeFunctionCallInOnePress(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("1");
    e.appendOperator("+");
    e.appendFunction("log");
    if (!e.expr.equals("1+log(")) {
        logger.debug("setup expected '1+log(' got '" + e.expr + "'");
        return false;
    }
    e.backspace();
    if (!e.expr.equals("1+")) {
        logger.debug("expected one backspace to remove the whole call, got '" + e.expr + "'");
        return false;
    }
    return true;
}

// Once something's been typed inside the call, backspace goes back to
// deleting one character at a time - only a just-opened, still-empty call
// gets removed atomically.
(:test)
function testBackspaceInsideFunctionArgDeletesOneCharacter(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendFunction("log");
    e.appendDigit("3");
    e.backspace();
    return e.expr.equals("log(");
}

// A function name that's a suffix of another one ("sin" inside "asin(")
// must not get swallowed - the whole, correct name ("asin(") is what
// backspace removes.
(:test)
function testBackspaceRemovesLongerFunctionNameNotJustSuffix(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendFunction("asin");
    e.backspace();
    return e.expr.equals("");
}

// X^2=4 isn't affine, so the old fit-only solver rejected it outright. Now
// that solveEquationForDisplay() falls back to solveNumeric() for anything
// non-affine, this - and any other equation with a real root - solves
// instead of erroring. The scan runs from very negative to very positive,
// so it lands on the x<0 branch's root (-2) before the x>0 branch's (2).
(:test)
function testNonlinearEquationNowSolvesInsteadOfErroring(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendConstant("X");
    e.appendOperator("^");
    e.appendDigit("2");
    e.insertEquals();
    e.appendDigit("4");
    e.evaluate();
    if (e.errorState) {
        logger.debug("expected x^2=4 to solve, got error");
        return false;
    }
    if (!e.expr.equals("X=-2")) {
        logger.debug("expected 'X=-2' got '" + e.expr + "'");
        return false;
    }
    return true;
}

(:test)
function testMod(logger as Test.Logger) as Boolean {
    var p = new ExprParser("7mod3", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 1.0d, logger);
}

(:test)
function testInverseTrig(logger as Test.Logger) as Boolean {
    var p = new ExprParser("asin(1)", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 90.0d, logger);
}

(:test)
function testCbrtAndAbs(logger as Test.Logger) as Boolean {
    var p = new ExprParser("cbrt(-8)+abs(-3)", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 1.0d, logger);
}

(:test)
function testFloorCeil(logger as Test.Logger) as Boolean {
    var p = new ExprParser("floor(2.7)+ceil(2.1)", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 5.0d, logger);
}

(:test)
function testFactorial(logger as Test.Logger) as Boolean {
    var p = new ExprParser("fact(5)", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 120.0d, logger);
}

(:test)
function testScientificNotationEntry(logger as Test.Logger) as Boolean {
    // What the "EE" button produces: 1.5*10^3 = 1500
    var p = new ExprParser("1.5*10^3", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 1500.0d, logger);
}

// (),[],{} all group identically - only the smart-bracket buttons (below)
// care which glyph is which.
(:test)
function testSquareAndCurlyBrackets(logger as Test.Logger) as Boolean {
    var p = new ExprParser("2*[3+{1+1}]", 0.0d, {} as Dictionary<String, Double>);
    var v = p.parse();
    return !p.error && near(v, 10.0d, logger);
}

(:test)
function testMismatchedBracketTypeErrors(logger as Test.Logger) as Boolean {
    var p = new ExprParser("(2+3]", 0.0d, {} as Dictionary<String, Double>);
    p.parse();
    if (!p.error) {
        logger.debug("expected error on mismatched bracket types");
        return false;
    }
    return true;
}

// openParen()/closeParen() pick the glyph by nesting depth: (), then [],
// then {} for anything deeper - and closeParen() always matches whichever
// type is currently innermost.
(:test)
function testSmartBracketButtonsPickGlyphByDepth(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.openParen();
    e.appendDigit("1");
    e.openParen();
    e.appendDigit("2");
    e.openParen();
    e.appendDigit("3");
    e.closeParen();
    e.closeParen();
    e.closeParen();
    if (!e.expr.equals("(1[2{3}])")) {
        logger.debug("expected '(1[2{3}])' got '" + e.expr + "'");
        return false;
    }
    return true;
}

// "LHS=RHS" with no letter on either side isn't an equation to solve for
// an unknown - it's just two values, so "=" shows their difference (0
// means they're actually equal) instead of erroring.
(:test)
function testSolveWithNoVariableShowsDifference(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("1");
    e.appendDigit("0");
    e.insertEquals();
    e.appendDigit("4");
    e.appendOperator("+");
    e.appendDigit("3");
    e.evaluate();
    if (e.errorState) {
        logger.debug("expected no error when no variable is present");
        return false;
    }
    if (!e.expr.equals("3")) {
        logger.debug("expected '3' (10 - (4+3)) got '" + e.expr + "'");
        return false;
    }
    return true;
}

(:test)
function testSolveWithNoVariableEqualSidesGivesZero(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("5");
    e.insertEquals();
    e.appendDigit("5");
    e.evaluate();
    return !e.errorState && e.expr.equals("0");
}

// The unknown in a denominator ("3/x") isn't affine, so the old
// three-sample-point fit rejected it (and sampling at x=0 first would have
// hit the division-by-zero guard anyway). solveEquationForDisplay()'s
// numeric fallback (solveAffine -> solveNumeric/bisectRoot) must still find
// the one real root: 8/1=3/x -> x=3/8.
(:test)
function testSolveEquationWithVariableInDenominator(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("8");
    e.appendOperator("/");
    e.appendDigit("1");
    e.insertEquals();
    e.appendDigit("3");
    e.appendOperator("/");
    e.appendConstant("X");
    e.evaluate();
    if (e.errorState) {
        logger.debug("expected 8/1=3/x to solve, got error");
        return false;
    }
    if (!e.expr.equals("X=0.375")) {
        logger.debug("expected 'X=0.375' got '" + e.expr + "'");
        return false;
    }
    return true;
}

// The unknown on both sides, with a reciprocal on one of them, is also
// non-affine ("x+2=8/x" clears to x^2+2x-8=0, i.e. (x+4)(x-2)=0). The
// numeric fallback scans from very negative to very positive, so it finds
// the x<0 branch's single root (-4) before the x>0 branch's (2).
(:test)
function testSolveEquationWithVariableOnBothSidesNonlinear(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendConstant("X");
    e.appendOperator("+");
    e.appendDigit("2");
    e.insertEquals();
    e.appendDigit("8");
    e.appendOperator("/");
    e.appendConstant("X");
    e.evaluate();
    if (e.errorState) {
        logger.debug("expected x+2=8/x to solve, got error");
        return false;
    }
    if (!e.expr.equals("X=-4")) {
        logger.debug("expected 'X=-4' got '" + e.expr + "'");
        return false;
    }
    return true;
}

// A plain affine equation with the unknown on both sides already worked
// before this fix (the fast solveAffine path handles it exactly) - pinned
// here as a regression guard now that solveEquationForDisplay routes
// through solveAffine/solveNumeric instead of one inline fit.
(:test)
function testSolveEquationWithVariableOnBothSidesLinear(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("2");
    e.appendConstant("X");
    e.appendOperator("+");
    e.appendDigit("3");
    e.insertEquals();
    e.appendDigit("5");
    e.appendConstant("X");
    e.appendOperator("-");
    e.appendDigit("1");
    e.evaluate();
    return !e.errorState && e.expr.equals("X=1.333333");
}

// Every letter but E is now offered on the VAR screen (calc-for-garminView
// .VAR_LETTERS), including ones that are the first letter of a real
// function name (S/C/T/L/A/F/M) - solving an equation for one of those
// must work exactly like any other letter.
(:test)
function testSolveEquationForPreviouslyExcludedLetter(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendConstant("S");
    e.appendOperator("+");
    e.appendDigit("2");
    e.insertEquals();
    e.appendDigit("1");
    e.appendDigit("0");
    e.evaluate();
    return !e.errorState && e.expr.equals("S=8");
}

// appendConstant() must insert an explicit "*" between two letters typed
// back-to-back, so tapping e.g. "S" then "I" then "N" from the VAR screen
// multiplies three variables instead of silently parsing as sin(...) -
// the reason all 26-minus-E letters can safely be offered as variables.
(:test)
function testAppendConstantInsertsMultiplyBetweenAdjacentLetters(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendConstant("X");
    e.appendConstant("Y");
    if (!e.expr.equals("X*Y")) {
        logger.debug("expected 'X*Y' got '" + e.expr + "'");
        return false;
    }
    // A letter after a digit/operator/paren must NOT get an extra "*" -
    // implicit multiplication and explicit operators already cover those.
    var e2 = new CalculatorEngine();
    e2.clearVariables();
    e2.appendDigit("2");
    e2.appendConstant("X");
    if (!e2.expr.equals("2X")) {
        logger.debug("expected '2X' got '" + e2.expr + "'");
        return false;
    }
    return true;
}

// toggleFraction() flips the last "=" result between decimal and a/b, and
// back again - it's a display toggle, not a recompute.
(:test)
function testToggleFractionShowsAndHidesFraction(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("1");
    e.appendOperator("/");
    e.appendDigit("3");
    e.evaluate();
    e.toggleFraction();
    if (!e.expr.equals("1/3")) {
        logger.debug("expected '1/3' got '" + e.expr + "'");
        return false;
    }
    e.toggleFraction();
    if (!e.expr.equals("0.333333")) {
        logger.debug("expected '0.333333' back in decimal, got '" + e.expr + "'");
        return false;
    }
    return true;
}

// An exact integer result has nothing to gain from fraction form, so
// toggling it is a no-op.
(:test)
function testToggleFractionOnIntegerIsUnchanged(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    e.appendDigit("4");
    e.evaluate();
    e.toggleFraction();
    return !e.errorState && e.expr.equals("4");
}

// computeSolutionSteps() walks "2+3*4" precedence-first: 3*4 before 2+...,
// then the final answer - used by the history detail screen.
(:test)
function testComputeSolutionStepsRespectsPrecedence(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    var steps = e.computeSolutionSteps("2+3*4", null);
    if (steps.size() != 3 || !steps[0].equals("2+3*4") || !steps[1].equals("2+12") || !steps[2].equals("14")) {
        logger.debug("expected ['2+3*4','2+12','14'] got " + joinSteps(steps));
        return false;
    }
    return true;
}

// Parens are solved before anything outside them, one step at a time.
(:test)
function testComputeSolutionStepsInnermostParensFirst(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    var steps = e.computeSolutionSteps("(2+3)*4", null);
    if (steps.size() != 3 || !steps[0].equals("(2+3)*4") || !steps[1].equals("(5)*4") || !steps[2].equals("20")) {
        logger.debug("expected ['(2+3)*4','(5)*4','20'] got " + joinSteps(steps));
        return false;
    }
    return true;
}

// A function call only collapses once its argument is a plain number.
(:test)
function testComputeSolutionStepsFunctionCall(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    var steps = e.computeSolutionSteps("sqrt(9)+1", null);
    if (steps.size() != 3 || !steps[0].equals("sqrt(9)+1") || !steps[1].equals("3+1") || !steps[2].equals("4")) {
        logger.debug("expected ['sqrt(9)+1','3+1','4'] got " + joinSteps(steps));
        return false;
    }
    return true;
}

// An equation isn't an order-of-operations walk - just the equation and its
// solved form, two steps total.
(:test)
function testComputeSolutionStepsEquation(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    var steps = e.computeSolutionSteps("2X+3=7", null);
    if (steps.size() != 2 || !steps[0].equals("2X+3=7") || !steps[1].equals("X=2")) {
        logger.debug("expected ['2X+3=7','X=2'] got " + joinSteps(steps));
        return false;
    }
    return true;
}

// If the step walk can't fully resolve an expression, the already-known
// answer (recorded in history when it was first computed) must still show
// up as the final step rather than leaving the user with no answer at all.
(:test)
function testComputeSolutionStepsFallsBackToKnownAnswer(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.clearVariables();
    var steps = e.computeSolutionSteps("2+3*4", "14");
    if (!steps[steps.size() - 1].equals("14")) {
        logger.debug("expected last step '14' got " + joinSteps(steps));
        return false;
    }
    if (steps.size() != 3) {
        logger.debug("known answer already reached by the walk shouldn't be duplicated, got " + joinSteps(steps));
        return false;
    }
    return true;
}

function joinSteps(steps as Array<String>) as String {
    var out = "";
    for (var i = 0; i < steps.size(); i++) {
        out += (i > 0 ? "," : "") + steps[i];
    }
    return out;
}

function near(a as Double, b as Double, logger as Test.Logger) as Boolean {
    var d = a - b;
    if (d < 0.0d) {
        d = -d;
    }
    if (d > 0.0001d) {
        logger.debug("expected " + b + " got " + a);
        return false;
    }
    return true;
}

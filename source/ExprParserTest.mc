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

(:test)
function testEquationEngine(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.appendDigit("2");
    e.appendConstant("X");
    e.appendOperator("+");
    e.appendDigit("3");
    e.evaluate();
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
    // 3*(X-2)=9  ->  X=5
    e.appendDigit("3");
    e.appendOperator("*");
    e.openParen();
    e.appendConstant("X");
    e.appendOperator("-");
    e.appendDigit("2");
    e.closeParen();
    e.evaluate();
    e.appendDigit("9");
    e.evaluate();
    return !e.errorState && e.expr.equals("X=5");
}

// Solving isn't hardcoded to X any more - any bare single letter that isn't
// a stored variable works: "2Y+3=7" -> "Y=2".
(:test)
function testEquationSolvesForY(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.appendDigit("2");
    e.appendConstant("Y");
    e.appendOperator("+");
    e.appendDigit("3");
    e.evaluate();
    e.appendDigit("7");
    e.evaluate();
    if (!e.expr.equals("Y=2")) {
        logger.debug("expected 'Y=2' got '" + e.expr + "'");
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

(:test)
function testNonlinearEquationErrors(logger as Test.Logger) as Boolean {
    var e = new CalculatorEngine();
    e.appendConstant("X");
    e.appendOperator("^");
    e.appendDigit("2");
    e.evaluate();
    e.appendDigit("4");
    e.evaluate();
    if (!e.errorState) {
        logger.debug("expected nonlinear equation to error, got '" + e.expr + "'");
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

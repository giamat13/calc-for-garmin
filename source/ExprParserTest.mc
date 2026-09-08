import Toybox.Test;
import Toybox.Lang;

(:test)
function testBasicArithmetic(logger as Test.Logger) as Boolean {
    var p = new ExprParser("2+3*4", 0.0d);
    var v = p.parse();
    return !p.error && near(v, 14.0d, logger);
}

(:test)
function testParens(logger as Test.Logger) as Boolean {
    var p = new ExprParser("(2+3)*4", 0.0d);
    var v = p.parse();
    return !p.error && near(v, 20.0d, logger);
}

(:test)
function testPower(logger as Test.Logger) as Boolean {
    var p = new ExprParser("2^3^2", 0.0d);
    var v = p.parse();
    // right-associative: 2^(3^2) = 2^9 = 512
    return !p.error && near(v, 512.0d, logger);
}

(:test)
function testFunctionAndConst(logger as Test.Logger) as Boolean {
    var p = new ExprParser("sqrt(9)+π", 0.0d);
    var v = p.parse();
    return !p.error && near(v, 3.0d + 3.14159265d, logger);
}

(:test)
function testUnaryMinus(logger as Test.Logger) as Boolean {
    var p = new ExprParser("-2^2", 0.0d);
    var v = p.parse();
    // unary minus applied after power of the primary: -(2^2) = -4
    return !p.error && near(v, -4.0d, logger);
}

(:test)
function testDivideByZeroErrors(logger as Test.Logger) as Boolean {
    var p = new ExprParser("5/0", 0.0d);
    p.parse();
    if (!p.error) {
        logger.debug("expected error on divide by zero");
        return false;
    }
    return true;
}

(:test)
function testPercent(logger as Test.Logger) as Boolean {
    var p = new ExprParser("50%", 0.0d);
    var v = p.parse();
    return !p.error && near(v, 0.5d, logger);
}

(:test)
function testVariableX(logger as Test.Logger) as Boolean {
    var p = new ExprParser("2*X+1", 5.0d);
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

import Toybox.Lang;
import Toybox.Math;

// Classic accumulator-style calculator engine (press digit/op like a real
// calculator, no expression parsing needed).
class CalculatorEngine {

    var display as String = "0";
    var pendingOp as String? = null;
    var pendingValue as Double = 0.0d;
    var freshEntry as Boolean = true;
    var errorState as Boolean = false;

    private const E = 2.718281828459045d;

    function initialize() {
    }

    function inputDigit(d as String) as Void {
        if (errorState) {
            clear();
        }
        if (freshEntry) {
            display = d.equals(".") ? "0." : d;
            freshEntry = false;
            return;
        }
        if (d.equals(".") && display.find(".") != null) {
            return;
        }
        if (display.equals("0") && !d.equals(".")) {
            display = d;
        } else if (display.length() < 12) {
            display = display + d;
        }
    }

    function backspace() as Void {
        if (errorState || freshEntry) {
            return;
        }
        if (display.length() <= 1) {
            display = "0";
            freshEntry = true;
            return;
        }
        display = display.substring(0, display.length() - 1) as String;
        if (display.equals("-")) {
            display = "0";
            freshEntry = true;
        }
    }

    function setOperator(op as String) as Void {
        if (errorState) {
            return;
        }
        if (pendingOp != null && !freshEntry) {
            compute();
            if (errorState) {
                return;
            }
        }
        pendingValue = currentValue();
        pendingOp = op;
        freshEntry = true;
    }

    function equalsPressed() as Void {
        compute();
        pendingOp = null;
    }

    function percent() as Void {
        if (errorState) {
            return;
        }
        var cur = currentValue();
        var result = (pendingOp != null) ? (pendingValue * cur / 100.0d) : (cur / 100.0d);
        setDisplay(result);
    }

    function negate() as Void {
        if (errorState) {
            return;
        }
        setDisplay(-currentValue());
    }

    function unary(op as String) as Void {
        if (errorState) {
            return;
        }
        var cur = currentValue();
        var result = 0.0d;
        if (op.equals("sin")) {
            result = Math.sin(cur * Math.PI / 180.0d) as Double;
        } else if (op.equals("cos")) {
            result = Math.cos(cur * Math.PI / 180.0d) as Double;
        } else if (op.equals("tan")) {
            result = Math.tan(cur * Math.PI / 180.0d) as Double;
        } else if (op.equals("sqrt")) {
            if (cur < 0.0d) {
                setError();
                return;
            }
            result = Math.sqrt(cur) as Double;
        } else if (op.equals("sqr")) {
            result = cur * cur;
        } else if (op.equals("inv")) {
            if (cur == 0.0d) {
                setError();
                return;
            }
            result = 1.0d / cur;
        } else if (op.equals("log")) {
            if (cur <= 0.0d) {
                setError();
                return;
            }
            result = Math.log(cur, 10.0d) as Double;
        } else if (op.equals("ln")) {
            if (cur <= 0.0d) {
                setError();
                return;
            }
            result = Math.log(cur, E) as Double;
        }
        setDisplay(result);
    }

    function constant(name as String) as Void {
        if (name.equals("pi")) {
            setDisplay(Math.PI.toDouble());
        } else if (name.equals("e")) {
            setDisplay(E);
        }
    }

    function clear() as Void {
        display = "0";
        pendingOp = null;
        pendingValue = 0.0d;
        freshEntry = true;
        errorState = false;
    }

    function currentValue() as Double {
        return display.toDouble() as Double;
    }

    private function compute() as Void {
        var op = pendingOp;
        if (op == null) {
            return;
        }
        var cur = currentValue();
        var result = 0.0d;
        if (op.equals("+")) {
            result = pendingValue + cur;
        } else if (op.equals("-")) {
            result = pendingValue - cur;
        } else if (op.equals("*")) {
            result = pendingValue * cur;
        } else if (op.equals("/")) {
            if (cur == 0.0d) {
                setError();
                return;
            }
            result = pendingValue / cur;
        } else if (op.equals("^")) {
            result = Math.pow(pendingValue, cur) as Double;
        }
        setDisplay(result);
    }

    private function setDisplay(v as Double) as Void {
        display = formatNumber(v);
        freshEntry = true;
    }

    private function setError() as Void {
        display = "Error";
        errorState = true;
        pendingOp = null;
        freshEntry = true;
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

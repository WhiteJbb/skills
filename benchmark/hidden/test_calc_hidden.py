import os
import sys

sys.path.insert(0, os.getcwd())
from calc import evaluate


def expect_error(e):
    try:
        evaluate(e)
    except ValueError:
        return
    raise AssertionError("expected ValueError for %r" % (e,))


def run():
    assert evaluate("2+3*4") == 14
    assert evaluate(" 2 + 3 ") == 5
    # rule 2: precedence corners
    assert evaluate("-2^2") == -4
    assert evaluate("(-2)^2") == 4
    assert evaluate("2*-3") == -6
    # rule 3: right-assoc power, signed exponent
    assert evaluate("2^3^2") == 512
    assert evaluate("2^-3") == 0.125
    # rule 4: repeated unary minus
    assert evaluate("--5") == 5
    assert evaluate("2--3") == 5
    assert evaluate("-3--3") == 0
    # rule 5: float result
    assert evaluate("6/4") == 1.5
    assert isinstance(evaluate("1+1"), float)
    # rule 7: division by zero
    expect_error("1/(3-3)")
    expect_error("0^-1")
    # rule 6: malformed inputs
    for bad in ["", "  ", "2+", "*2", "1 2", "5.", ".5", "(2", "2)", "()", "2$3", "2*/3", "2^"]:
        expect_error(bad)
    # rule 8: no eval/exec/ast
    src = open("calc.py", encoding="utf-8").read()
    for banned in ["eval(", "exec(", "import ast"]:
        assert banned not in src, "banned construct: " + banned
    print("HIDDEN OK")


if __name__ == "__main__":
    run()

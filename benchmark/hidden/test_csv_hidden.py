import os
import sys

sys.path.insert(0, os.getcwd())
from csvlite import parse_csv


def expect_error(text):
    try:
        parse_csv(text)
    except ValueError:
        return
    raise AssertionError("expected ValueError for %r" % (text,))


def run():
    # basics must still hold
    assert parse_csv("a,b,c") == [["a", "b", "c"]]
    assert parse_csv("") == []
    # rule 3: doubled quote is a literal quote
    assert parse_csv('"he said ""hi""",x') == [['he said "hi"', "x"]]
    assert parse_csv('""""') == [['"']]
    assert parse_csv('""') == [[""]]
    # rule 2: newlines inside quoted fields (LF and CRLF)
    assert parse_csv('"a\nb",c') == [["a\nb", "c"]]
    assert parse_csv('"a\r\nb",c') == [["a\r\nb", "c"]]
    # rule 1: CRLF record separator
    assert parse_csv("a,b\r\n1,2\r\n") == [["a", "b"], ["1", "2"]]
    # rule 4: trailing newline ignored, empty middle line is [""]
    assert parse_csv("a,b\n") == [["a", "b"]]
    assert parse_csv("a\n\nb") == [["a"], [""], ["b"]]
    # empty fields
    assert parse_csv(",,\na,,b") == [["", "", ""], ["a", "", "b"]]
    # rule 5: error cases
    expect_error('a"b')
    expect_error('"abc')
    expect_error('"a"b,c')
    # rule 6: csv module ban
    src = open("csvlite.py", encoding="utf-8").read()
    assert "import csv" not in src and "from csv" not in src, "csv module used"
    print("HIDDEN OK")


if __name__ == "__main__":
    run()

from backup import backup_snapshot
from exporter import export_rows
from storage import save


def run():
    assert save([1, 2], format="json") == "[1, 2]"
    assert export_rows([[1, "a"]]) == 'EXPORT\n[[1, "a"]]'
    assert backup_snapshot({"k": 1}) == 'BACKUP:{"k": 1}'
    print("OK")


if __name__ == "__main__":
    run()

include std/unittest.e
include std/datetime.e
include edbi/edbi.e

/* Open/Edit a database, if this fails, abort the rest of the test */
assert("Open database",edbi:open("sqlite3://example.db"))

/* Test fundamental EDBI routines with generic SQL statements */
test_true("Drop table test",edbi:execute("DROP TABLE people"))

test_report()

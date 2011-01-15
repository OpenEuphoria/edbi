--
-- Example edbi use
-- 

include std/datetime.e
include edbi/edbi.e

sequence data = {
    { "Ronald Mc'Donald", 29382, datetime:subtract(datetime:new(), 32, YEARS) },
    { "Super Man", 55555, datetime:new(1944, 5, 18) },
    { "Wonder Woman", 21232, datetime:new(1972, 9, 29) }
}

edbi:set_driver_path("../drivers")
edbi:db_handle dbh = edbi:open("sqlite3://example.db")
--edbi:db_handle dbh = edbi:open("mysql://user:secret@localhost/test")
--edbi:db_handle dbh = edbi:open("pgsql://user:secret@localhost/pgtest")

edbi:execute("DROP TABLE people")
edbi:execute("CREATE TABLE people (name VARCHAR(30), zip INTEGER, dob DATETIME)")

for i = 1 to length(data) do
    edbi:execute("INSERT INTO people VALUES (%s, %d, %D)", data[i])
end for

edbi:dbr_handle dbr = edbi:query("SELECT * FROM people")

while 1 do
    object o = edbi:next(dbr)
    if atom(o) then exit end if
    printf(1, "Name=%s, Zip=%d, Dob=%s\n", { o[1], o[2], datetime:format(o[3], "%m/%d/%Y") })
end while
edbi:closeq(dbr)

data = edbi:query_rows("SELECT * FROM people")
for i = 1 to length(data) do
	object o = data[i]
    printf(1, "Name=%s, Zip=%d, Dob=%s\n", { o[1], o[2], datetime:format(o[3], "%m/%d/%Y") })
end for

edbi:close()


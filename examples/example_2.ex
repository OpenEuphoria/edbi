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

edbi:set_driver_path("drivers")
edbi:db_handle dbh = edbi:open("eusql://example.db")
edbi:execute("CREATE TABLE people name AS SEQUENCE, zip AS INTEGER, dob AS DATE_TIME")

for i = 1 to length(data) do
    edbi:execute("INSERT INTO people (name, zip, dob) VALUES (%s, %d, %D)", data[i])
end for

--edbi:dbr_handle dbr = edbi:query("SELECT * FROM people")

--while 1 do
--    object o = edbi:next(dbr)
--    if atom(o) then exit end if
--    printf(1, "Name=%s, Zip=%d, Dob=%s\n", { o[1], o[2], datetime:format(o[3], "%m/%d/%Y") })
--end while

edbi:close()


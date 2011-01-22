include std/unittest.e
include std/datetime.e
include edbi/edbi.e
include std/get.e
edbi:set_driver_path("../drivers")

/* This should fail but does not! Trying to open a non-existing database still returns TRUE... */
--assert("Open non-existing database",edbi:open("mysql://spiderman:maryjane@192.168.1.100/NotExist"))

/* Open/Edit a database, if this fails, abort the rest of the test */
assert("Open database",edbi:open("mysql://spiderman:lynnlynn@192.168.1.100/UnitTest"))

/* ---------------------------------------------------------------------
                  First, look at Numeric types... 
--------------------------------------------------------------------- */
object numbers = {111,76.4,3.14159},
       types = {"INTEGER", "NUMERIC", "REAL"}
       
/* I can Drop tables in mysql but I can't seem to create them... So instead, just delete all values from the 
 table instead of dropping it and manually create the table TestNum... Why does creating a table fail? 
 NOTE: edbi:exeucte returns FALSE on success....    */ 
test_false("Delete all current table values",edbi:execute("DELETE FROM TestNum where a LIKE '%'"))

test_false("Insert values into TestNum",edbi:execute("INSERT INTO TestNum VALUES (%d,%f,%f)",numbers))

/* Now check to make sure we can read back the different types of numerics */
	/* Method 1 */
object data
data = edbi:query_rows("SELECT * FROM TestNum")

	for ii = 1 to length(types) do
		test_equal(sprintf("Checking %s data types with Query Rows...",{types[ii]}),numbers[ii],data[1][ii])
	end for
	
	/*  Method 2 */
edbi:dbr_handle dbr = edbi:query("SELECT * FROM TestNum")
data = edbi:next(dbr)	

	for ii = 1 to length(types) do
		test_equal(sprintf("Checking %s data types with Query...",{types[ii]}),numbers[ii],data[ii])
	end for

/* It appears that I can only work with 1 table at a time. If I don't close out the database and re-open,
 * none of the Strings and Dates check will work... Comment out the next two lines to check...*/
edbi:close()
assert("Open database",edbi:open("mysql://spiderman:lynnlynn@192.168.1.100/UnitTest"))

/* ---------------------------------------------------------------------
                      Look at strings and dates 
--------------------------------------------------------------------- */
object book = {"A Tale of Two Cities","Charles Dickens","English",datetime:new(1859, 1, 1, 23, 59, 0),datetime:new(2000,10,13)}
types = {"TEXT", "VARCHAR", "BLOB", "DATETIME", "DATE" }

/* Try deleting all values from the table instead of just dropping it... The table Test was create manually first...*/
test_false("Delete all current table values",edbi:execute("DELETE FROM TestString where a LIKE '%'"))
test_false("Insert values into string table",edbi:execute("INSERT INTO TestString VALUES (%s,%s,%s,%s,%D)",{book[1],book[2],book[3],datetime:format(book[4]),book[5]}))

	/* Method 1 */
data = edbi:query_rows("SELECT * FROM TestString")

	for ii = 1 to length(types) do
		test_equal(sprintf("Checking %s data types with Query Rows...",{types[ii]}),book[ii],data[1][ii])
	end for

	/*  Method 2 */
dbr = edbi:query("SELECT * FROM TestString")
data = edbi:next(dbr)	

	for ii = 1 to length(types) do
		test_equal(sprintf("Checking %s data types with Query...",{types[ii]}),book[ii],data[ii])
	end for

edbi:close()
/* ---------------------------------------------------------------------
 *                          End of unit test
--------------------------------------------------------------------- */
test_report()

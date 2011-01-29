include std/unittest.e
include std/datetime.e
include edbi/edbi.e
include std/get.e
edbi:set_driver_path("../drivers")

/* ---------------------------------------------------------------------
                          NOTES: 
  edbi:exeucte returns FALSE on success, which is how Mysql API works!   
  --------------------------------------------------------------------  */

/* Open/Edit a database, if this fails, abort the rest of the test */
assert("Open database",edbi:open("sqlite3://unitTest.db"))

/* Organize the drop table statements together because the second
 seems to fail if not done in succession */
test_false("Drop table TestNum",edbi:execute("DROP TABLE TestNum"))
test_false("Drop table TestString",edbi:execute("DROP TABLE TestString"))

/* ---------------------------------------------------------------------
                  First, look at Numeric types... 
--------------------------------------------------------------------- */
object numbers = {111,76.4,3.14159},
       types = {"INTEGER", "NUMERIC", "REAL"}
test_false("Create table TestNum",edbi:execute("CREATE TABLE TestNum (a %v, b %v, c %v)",types))
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
	
/* ---------------------------------------------------------------------
                      Look at strings and dates 
--------------------------------------------------------------------- */
object book = {"A Tale of Two Cities","Charles Dickens","English",datetime:new(1859, 1, 1, 23, 59, 0),datetime:new(2000,10,13)}
types = {"TEXT", "VARCHAR", "BLOB", "DATETIME", "DATE" }
test_false("Create table TestString",edbi:execute("CREATE TABLE TestString (title %v, author %v, language %v, date %v, purchased %v)",types))
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

/* ---------------------------------------------------------------------
                      Check general SQL commands 
Is this an appropriate use of query_rows or is there another method to do this?
--------------------------------------------------------------------- */
test_equal(".tables check",{"Numeric","String"},edbi:query_rows(".tables"))
test_equal(".schema check",{"CREATE TABLE STRING..."},edbi:query_rows(".schema Numeric"))

edbi:close()
/* ---------------------------------------------------------------------
 *                          End of unit test
--------------------------------------------------------------------- */
test_report()

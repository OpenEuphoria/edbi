include std/unittest.e
include std/datetime.e
include edbi/edbi.e
include std/get.e
edbi:set_driver_path("../drivers")

constant USER="user"
constant PASSWORD="secret"

/* ---------------------------------------------------------------------
                          NOTES: 
  edbi:exeucte returns FALSE on success, which is how Mysql API works!   
  --------------------------------------------------------------------  */

/* This should fail but does not! Trying to open a non-existing database still returns TRUE... */
--assert("Open non-existing database",edbi:open("mysql://spiderman:maryjane@192.168.1.100/NotExist"))

/* Open/Edit a database, if this fails, abort the rest of the test */
assert("Open database",edbi:open( sprintf("mysql://%s:%s@localhost/UnitTest",{USER,PASSWORD})  ))

/* ---------------------------------------------------------------------
                  First, look at Numeric types... 
--------------------------------------------------------------------- */
object numbers = {111,76.4,3.14159},
       types = {"INTEGER", "DOUBLE", "REAL"}
       
/* The issue with createing a new table is the ' ' placed around the variable types. Edbi:execute uses sprintf_sql 
 which for %s and %S put apostrophes around strings. This is necessary inserting strings but will cause an error when
 creating a new database... This is solved by using %v for verbatim! */
test_false("Drop table TestNum",edbi:execute("DROP TABLE TestNum"))
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

/* It appears that I can only work with 1 table at a time. If I don't close out the database and re-open,
 * none of the Strings and Dates check will work... Comment out the next two lines to check...*/
edbi:close()
assert("Open database",edbi:open( sprintf("mysql://%s:%s@localhost/UnitTest",{USER,PASSWORD})  ))

/* ---------------------------------------------------------------------
                      Look at strings and dates 
--------------------------------------------------------------------- */

object book = {"A Tale of Two Cities","Charles Dickens","English",datetime:new(1859, 1, 1, 23, 59, 0),datetime:new(2000,10,13)}
types = {"TEXT", "VARCHAR(30)", "BLOB", "DATETIME", "DATE" }
test_false("Drop table TestString",edbi:execute("DROP TABLE TestString"))
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

edbi:close()
/* ---------------------------------------------------------------------
 *                          End of unit test
--------------------------------------------------------------------- */
test_report()

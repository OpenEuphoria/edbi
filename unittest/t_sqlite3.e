include std/unittest.e
include std/datetime.e
include edbi/edbi.e
include std/get.e
edbi:set_driver_path("../drivers")


/* Open/Edit a database, if this fails, abort the rest of the test */
assert("Open database",edbi:open("sqlite3://unitTest.db"))

/* Test fundamental EDBI routines with generic SQL statements 
 * It appears that edbi:execute returns FALSE on success, i.e. no errors... 
 * Is this expected or a bug? */

/* ---------------------------------------------------------------------
                  First, look at Numeric types... 
--------------------------------------------------------------------- */
object numbers = {111,76.4,3.14159}
test_false("Drop table Numeric",edbi:execute("DROP TABLE Numeric"))
test_false("Create table Numeric",edbi:execute("CREATE TABLE Numeric (one INTEGER, two FLOAT, three DOUBLE)"))
test_false("Insert values into Numeric",edbi:execute("INSERT INTO Numeric VALUES (%d,%f,%f)",numbers))

/* Now check to make sure we can read back the different types of numerics */
	/* Method 1 */
object data
data = edbi:query_rows("SELECT * FROM Numeric")
test_equal("Checking numeric data types with Query Rows...",numbers,data[1])

	/*  Method 2 */
edbi:dbr_handle dbr = edbi:query("SELECT * FROM Numeric")
data = edbi:next(dbr)	
test_equal("Checking numeric data types with Query...",numbers,data)

/* ---------------------------------------------------------------------
                      Look at strings and dates 
--------------------------------------------------------------------- */
object book = {"A Tale of Two Cities","Charles Dickens","English",datetime:new(1859, 1, 1, 23, 59, 0),datetime:new(2000,10,13)}
test_false("Drop table String",edbi:execute("DROP TABLE String"))
test_false("Create table String",edbi:execute("CREATE TABLE String (title TEXT, author VARCHAR(30), language BLOB, date DATETIME, purchased DATE)"))
test_false("Insert values into String",edbi:execute("INSERT INTO String VALUES (%s,%s,%s,%s,%D)",{book[1],book[2],book[3],datetime:format(book[4]),book[5]}))

	/* Method 1 */
data = edbi:query_rows("SELECT * FROM String")
test_equal("Checking string data types with Query Rows..",book,data[1])

	/*  Method 2 */
dbr = edbi:query("SELECT * FROM String")
data = edbi:next(dbr)	
test_equal("Checking string data types with Query...",book,data)

edbi:close()
/* ---------------------------------------------------------------------
 *                          End of unit test
--------------------------------------------------------------------- */
test_report()

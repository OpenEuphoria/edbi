--
-- Copyright (C) 2009,2010 by Jeremy Cowgar <jeremy@cowgar.com>
--
-- This file is part of edbi.
--
-- edbi is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as
-- published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- edbi is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with edbi.  If not, see <http://www.gnu.org/licenses/>.
--

namespace edbi

--****
-- == Euphoria DBI (DataBase Interface)
--
-- EDBI allows the programmer to use any supporting database with a unified database
-- interface. Database drivers are loaded dynamically and can be written for any database
-- server or client. Multiple database connections can be managed at the same time across
-- multiple drivers. To use a different database server or driver, simply use the correct
-- connection string. For example:
--
-- <eucode>
-- edbi:open("sqlite3://people.db")
-- edbi:open("mysql://localhost?dbname=people")
-- edbi:open("pgsql://localhost?dbname=people")
-- </eucode>
--
-- EDBI automatically maps database values and types into Euphoria native types. For
-- instance, a VARCHAR comes back as a sequence, a NUMERIC or DECIMAL as an atom, an
-- INTEGER as an integer, a DATE, TIME, DATETIME or TIMESTAMP as a datetime, etc...
--
-- Querying EDBI allows the use of Euphoria types directly as well:
--
-- <eucode>
-- edbi:query("SELECT * FROM people WHERE zip=%d AND dob < %D", { 30293,
--     datetime:subtract(datetime:new(), 18, YEARS) })
-- </eucode>
--
-- === Available Drivers
--
-- At this point in time, only the reference driver is available for SQLite3. It's connection
-- string is: ##sqlite3://filename##. Other database drivers will come in due time, starting next
-- with MySQL and then PostgreSQL.
--
-- Database drivers are very easy to write. Please see the source code, and look at
-- ##drivers/sqlite3/## for more information and a good example.
--
-- Database drivers must implement a common, but very minimal API. The methods the database driver
-- must implement are:
--
-- # edbi_open
-- # edbi_close
-- # edbi_get_error_code
-- # edbi_get_error_message
-- # edbi_execute
-- # edbi_query
-- # edbi_next
-- # edbi_closeq
-- # edbi_last_insert_id
-- # edbi_total_changes
-- # edbi_is_empty
--
-- Database drivers can be implemented in C for sheer speed or in Euphoria compiled as a DLL.
--
-- === Current Status
--
-- EDBI is brand new and API changes will take place. I am seeking user input and user help for
-- other drivers. Currently EDBI is only tested on Windows, although with a slight change to the
-- binary driver build files, it should work with out source code change on all platforms that
-- Euphoria supports.
--
-- EDBI can be downloaded via SVN at, http://jeremy.cowgar.com/svn/edbi/trunk by issuing the
-- following commands
-- {{{
-- c:\projects> svn co http://jeremy.cowgar.com/svn/edbi/trunk edbi
-- }}}
-- This will include a pre-built sqlite driver.
--
-- Downloadable packages outside of SVN are not yet available as we are still early in the
-- development stages.
--
-- === An Example
--
-- <eucode>
-- --
-- -- Example edbi use
-- --
--
-- include std/datetime.e
-- include edbi/edbi.e
--
-- sequence data = {
--     { "Ronald Mc'Donald", 29382, datetime:subtract(datetime:new(), 32, YEARS) },
--     { "Super Man", 55555, datetime:new(1944, 5, 18) },
--     { "Wonder Woman", 21232, datetime:new(1972, 9, 29) }
-- }
--
-- edbi:set_driver_path("drivers")
-- edbi:db_handle dbh = edbi:open("sqlite3://example.db")
--
-- edbi:execute("DROP TABLE people")
-- edbi:execute("CREATE TABLE people (name VARCHAR(30), zip INTEGER, dob datetime)")
--
-- for i = 1 to length(data) do
--     edbi:execute("INSERT INTO people VALUES (%s, %d, %D)", data[i])
-- end for
--
-- edbi:dbr_handle dbr = edbi:query("SELECT * FROM people")
--
-- while 1 do
--     object o = edbi:next(dbr)
--     if atom(o) then exit end if
--     printf(1, "Name=%s, Zip=%d, Dob=%s\n", { o[1], o[2], datetime:format(o[3], "%m/%d/%Y") })
-- end while
--
-- edbi:close()
-- </eucode>
--

include std/datetime.e
include std/dll.e
include std/error.e
include std/eumem.e
include std/filesys.e
include std/get.e
include std/search.e
include std/sequence.e

include defs.e

--=================================================================================================
--
-- Supporting Functions
--
--=================================================================================================

function sqlDateTimeToDateTime(sequence sD)
    if length(sD) = 0 then
        return datetime:new()
    end if

    switch length(sD) do
    	case 8 then
            -- time only
            return datetime:new(0, 0, 0,
                defaulted_value(sD[1..2], 0),
                defaulted_value(sD[4..5], 0),
                defaulted_value(sD[7..8], 0))

        case 10 then
            -- date only
            return datetime:new(
                defaulted_value(sD[1..4], 0),
                defaulted_value(sD[6..7], 0),
                defaulted_value(sD[9..10], 0),
            	0, 0, 0)

        case 19 then
            -- date and time
            return datetime:new(
                defaulted_value(sD[1..4], 0),
                defaulted_value(sD[6..7], 0),
                defaulted_value(sD[9..10], 0),
                defaulted_value(sD[12..13], 0),
                defaulted_value(sD[15..16], 0),
                defaulted_value(sD[18..19], 0))
    end switch

    return datetime:new()
end function

function sprintf_sql(sequence sql, object values)
    sequence ns
    integer in_fmt, idx, ch

    if atom(values) or length(values) = 0 then
        return sql
    end if

    ns = ""
    in_fmt = 0
    idx = 1

    for i = 1 to length(sql) do
        ch = sql[i]

        if ch = '%' and in_fmt = 0 then
            in_fmt = 1
        elsif in_fmt = 1 then
            in_fmt = 0

			switch ch do
	            case '%' then
	                ns &= '%'
	            case 'b' then -- boolean
	                if values[idx] then
	                    ns &= "true"
	                else
	                    ns &= "false"
	                end if
	            case 'S' then -- unescaped string
	                ns &= sprintf("'%s'", {values[idx]})
	                idx += 1
	            case 's' then -- escaped string
					-- TODO: Use MySQL's escape string function
	                ns &= sprintf("'%s'", { match_replace("\\",
						match_replace("'", values[idx], "''", 0), "\\\\")})
	                idx += 1
	            case 'd' then  -- integer
	                ns &= sprintf("%d", {values[idx]})
	                idx += 1
	            case 'D' then -- date
	                -- TODO
	                ns &= datetime:format(values[idx], "'%Y-%m-%d'")
	                idx += 1
	            case 'T' then -- datetime
	                ns &= datetime:format(values[idx], "'%Y-%m-%d %H:%M:%S'")
	                idx += 1
	            case 't' then -- time
	                ns &= datetime:format(values[idx], "'%H:%M:%S'")
	                idx += 1
	            case 'f' then -- float
	                ns &= sprintf("%f", {values[idx]})
	                idx += 1
				case else
					crash("Unknown format character: %s (parameter #%d) in SQL %s",
						{ ch, idx, sql })
            end switch
        else
            ns &= ch
        end if
    end for

    return ns
end function

function get_seq(db_handle h)
    if h = 0 then h = def_dbh end if
    return ram_space[h]
end function

enum T_DRIVER, T_CONNSTR, T_DLL_H, T_DB_H, T_DOPEN, T_DCLOSE, T_DERROR_CODE,
	T_DERROR_MESSAGE, T_DEXECUTE, T_DLAST_INSERT_ID, T_DTOTAL_CHANGES,
    T_DQUERY, T_DNEXT, T_DCLOSEQ, T_END
enum Q_DB, Q_DBR, Q_COL_DATA, Q_ROW, Q_END

-- this can be any atom that can never be a valid dll handle
constant NOT_A_DLL = -9

-- Driver path
sequence driver_path = "."

-- Default database handle to use (last opened database)
db_handle def_dbh = 0

--=================================================================================================
--
-- Public
--
--=================================================================================================

--**
-- Defines a valid database connection handle.
--

public type db_handle(object o)
    if not atom(o) then goto "faail" end if
    if o = 0 then return 1 end if

    object d = ram_space[o]
    if not sequence(d) then goto "faail" end if
    if not length(d) = T_END then goto "faail" end if
    return 1
    label "faail"
    return 1
end type

--**
-- Defines a valid database result set handle.
--

public type dbr_handle(object o)
    if not atom(o) then goto "faail" end if
    if o = 0 then return 1 end if
    if o > length(ram_space) then goto "faail" end if

    object d = ram_space[o]
    if not sequence(d) then goto "faail" end if
    if not length(d) = Q_END then goto "faail" end if

    return 1
    label "faail"
    return 1
end type

--**
-- Set an alternate DBI driver path.
--

public procedure set_driver_path(sequence v)
    driver_path = v
end procedure

--**
-- Open a database connection.
--

public function open(sequence connection, object routines = 0 )
    sequence _ = split(connection, "://")
    sequence driver = _[1], conn_str = _[2]
    sequence dll_name1 = sprintf("%s/%s/edbi_%s.%s", { driver_path, driver, driver, SHARED_LIB_EXT })
    sequence dll_name2 = sprintf("%s/edbi_%s.%s", { driver_path, driver, SHARED_LIB_EXT })
    sequence dll_name3 = sprintf("edbi_%s.%s", { driver, SHARED_LIB_EXT })
    sequence m_seq = repeat(0, T_END)

    atom m_h = eumem:malloc()

	m_seq[T_DRIVER] = driver
    m_seq[T_CONNSTR] = conn_str
    if atom(routines) then
    m_seq[T_DLL_H] = open_dll({ dll_name1, dll_name2, dll_name3 })
    m_seq[T_DOPEN] = define_c_func(m_seq[T_DLL_H], "edbi_open", { E_SEQUENCE }, E_ATOM)
    m_seq[T_DCLOSE] = define_c_proc(m_seq[T_DLL_H], "edbi_close", { E_ATOM })
    m_seq[T_DERROR_CODE] = define_c_func(m_seq[T_DLL_H], "edbi_error_code", { E_ATOM }, E_INTEGER)
    m_seq[T_DERROR_MESSAGE] = define_c_func(m_seq[T_DLL_H], "edbi_error_message", { E_ATOM }, E_SEQUENCE)
    m_seq[T_DEXECUTE] = define_c_func(m_seq[T_DLL_H], "edbi_execute", { E_ATOM, E_SEQUENCE }, E_INTEGER)
    m_seq[T_DLAST_INSERT_ID] = define_c_func(m_seq[T_DLL_H], "edbi_last_insert_id", { E_ATOM, E_SEQUENCE }, E_ATOM)
    m_seq[T_DTOTAL_CHANGES] = define_c_func(m_seq[T_DLL_H], "edbi_total_changes", { E_ATOM }, E_ATOM)
    m_seq[T_DQUERY] = define_c_func(m_seq[T_DLL_H], "edbi_query", { E_ATOM, E_SEQUENCE }, E_SEQUENCE)
    m_seq[T_DNEXT] = define_c_func(m_seq[T_DLL_H], "edbi_next", { E_ATOM, E_INTEGER }, E_OBJECT)
    m_seq[T_DCLOSEQ] = define_c_proc(m_seq[T_DLL_H], "edbi_closeq", { E_ATOM })

	m_seq[T_DB_H] = c_func(m_seq[T_DOPEN], { conn_str })
    else
    m_seq[T_DLL_H] = NOT_A_DLL
    m_seq[T_DOPEN] = routines[1]
    m_seq[T_DCLOSE] = routines[2]
    m_seq[T_DERROR_CODE] = routines[3]
    m_seq[T_DERROR_MESSAGE] = routines[4]
    m_seq[T_DEXECUTE] = routines[5]
    m_seq[T_DLAST_INSERT_ID] = routines[6]
    m_seq[T_DTOTAL_CHANGES] = routines[7]
    m_seq[T_DQUERY] = routines[8]
    m_seq[T_DNEXT] = routines[9]
    m_seq[T_DCLOSEQ] = routines[10]

	m_seq[T_DB_H] = call_func(m_seq[T_DOPEN], { conn_str })
    end if

	ram_space[m_h] = m_seq

    def_dbh = m_h

	return m_h
end function

--**
-- Close a database connection
--

public procedure close(db_handle h = 0)
	sequence m_seq = get_seq(h)
	
    if m_seq[T_DLL_H] = NOT_A_DLL then
    call_proc(m_seq[T_DCLOSE], { m_seq[T_DB_H] })
    else
    c_proc(m_seq[T_DCLOSE], { m_seq[T_DB_H] })
    end if
end procedure

--**
-- Get the current error code, if any
--

public function error_code(db_handle h = 0)
    sequence m_seq = get_seq(h)

    if m_seq[T_DLL_H] = NOT_A_DLL then
    return call_func(m_seq[T_DERROR_CODE], { m_seq[T_DB_H] })
    else
    return c_func(m_seq[T_DERROR_CODE], { m_seq[T_DB_H] })
    end if
end function

--**
-- Get the current error message (text), if any
--

public function error_message(db_handle h = 0)
    sequence m_seq = get_seq(h)

    if m_seq[T_DLL_H] = NOT_A_DLL then
    return call_func(m_seq[T_DERROR_MESSAGE], { m_seq[T_DB_H] })
    else
    return c_func(m_seq[T_DERROR_MESSAGE], { m_seq[T_DB_H] })
    end if
end function

--**
-- Execute a SQL query that does not expect any record results.
--
-- See Also:
--   [[:total_changes]], [[:last_insert_id]]
--

public function execute(sequence sql, sequence data={}, db_handle h = 0)
	sequence m_seq = get_seq(h)

    if m_seq[T_DLL_H] = NOT_A_DLL then
    return call_func(m_seq[T_DEXECUTE], { m_seq[T_DB_H], sprintf_sql(sql, data) })
    else
    return c_func(m_seq[T_DEXECUTE], { m_seq[T_DB_H], sprintf_sql(sql, data) })
    end if
end function

--**
-- Get the unique id of the last inserted record.
--
-- See Also:
--   [[:execute]]
--

public function last_insert_id(sequence seq_name="", db_handle h = 0)
	sequence m_seq = get_seq(h)

    if m_seq[T_DLL_H] = NOT_A_DLL then
    return call_func(m_seq[T_DLAST_INSERT_ID], { m_seq[T_DB_H], seq_name })
    else
    return c_func(m_seq[T_DLAST_INSERT_ID], { m_seq[T_DB_H], seq_name })
    end if
end function

--**
-- Get the total number of changes caused by the last execute SQL statement.
--
-- See Also:
--   [[:execute]]
--

public function total_changes(db_handle h = 0)
	sequence m_seq = get_seq(h)

    if m_seq[T_DLL_H] = NOT_A_DLL then
    return call_func(m_seq[T_DTOTAL_CHANGES], { m_seq[T_DB_H] })
    else
    return c_func(m_seq[T_DTOTAL_CHANGES], { m_seq[T_DB_H] })
    end if
end function

--**
-- Issue a SQL query that expects record data as a result.
--
-- See Also:
--   [[:next]]
--

public function query(sequence sql, sequence data={}, db_handle h = 0)
    sequence m_seq = get_seq(h)
    atom m_q = eumem:malloc()

    sequence m_q_seq = repeat(0, Q_END)
    m_q_seq[Q_DB] = m_seq

    object tmp
    if m_seq[T_DLL_H] = NOT_A_DLL then
    tmp = call_func(m_seq[T_DQUERY], { m_seq[T_DB_H], sprintf_sql(sql, data) })
    else
    tmp = c_func(m_seq[T_DQUERY], { m_seq[T_DB_H], sprintf_sql(sql, data) })
    end if
	if error_code() then
		return error_code()
	end if

    m_q_seq[Q_DBR] = tmp[1]
    m_q_seq[Q_COL_DATA] = tmp[2]

    ram_space[m_q] = m_q_seq

    return m_q
end function

--**
-- Retrieve the next available row of data.
--
-- See Also:
--   [[:query]]
--

public function next(dbr_handle dbr)
    sequence m_q_seq = ram_space[dbr]
    sequence m_seq = m_q_seq[Q_DB]

	m_q_seq[Q_ROW] += 1

	object result
    if m_seq[T_DLL_H] = NOT_A_DLL then
	result = call_func(m_seq[T_DNEXT], { m_q_seq[Q_DBR], m_q_seq[Q_ROW] })
    else
	result = c_func(m_seq[T_DNEXT], { m_q_seq[Q_DBR], m_q_seq[Q_ROW] })
    end if
    if atom(result) then
        return result
    end if

    -- Do result processing here
    sequence col_data = m_q_seq[Q_COL_DATA]
    for i = 1 to length(col_data) do
        switch col_data[i][2] do
            case EU_ATOM, EU_INTEGER then
                result[i] = defaulted_value(result[i], 0)

            case EU_DATETIME then
                result[i] = sqlDateTimeToDateTime(result[i])
        end switch
    end for
    return result
end function

--**
-- Close an active query result.
--
-- See Also:
--   [[:query]]
--

public procedure closeq(dbr_handle dbr)
    sequence m_q_seq = ram_space[dbr]
    sequence m_seq = m_q_seq[Q_DB]

    if m_seq[T_DLL_H] = NOT_A_DLL then
	call_proc(m_seq[T_DCLOSEQ], { m_q_seq[Q_DBR] })
    else
	c_proc(m_seq[T_DCLOSEQ], { m_q_seq[Q_DBR] })
    end if
end procedure

--**
-- Query the database for all the rows in the result.
--
-- See Also:
--   [[:query]], [[:query_row]], [[:query_object]]
--

public function query_rows(sequence sql, sequence data={}, db_handle db = 0)
	dbr_handle dbr = query(sql, data, db)
	if error_code() then
		return error_code()
	end if

	sequence result = {}

	while 1 do
    	object o = edbi:next(dbr)
	    if atom(o) then exit end if
		result &= { o }
	end while

	closeq(dbr)

	return result
end function

--**
-- Query the database for just the first row. Querying the database, fetching the first row
-- and closing the query is all handled internally with this routine.
--
-- See Also:
--   [[:query_object]], [[:query]], [[:next]]
--

public function query_row(sequence sql, sequence data={}, db_handle db = 0)
    dbr_handle dbr = query(sql, data, db)    
	if error_code() then
		return error_code()
	end if

	object result = next(dbr)

	closeq(dbr)

	return result
end function

--**
-- Query the database for just the first object of the first row. Querying the database, fetching
-- the first object and closing the query is all handled internally with this routine. This routine
-- is helpful for queries such as ##"SELECT COUNT(*) FROM people"##.
--
-- See Also:
--   [[:query_row]], [[:query]], [[:next]]
--

public function query_object(sequence sql, sequence data={}, db_handle db = 0)
    object row = query_row(sql, data, db)
    if sequence(row) and length(row) > 0 then return row[1] end if
    return row
end function


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

include std/datetime.e as dt
include std/dll.e
include std/error.e
include std/get.e
include std/machine.e
include std/map.e
include std/search.e
include std/text.e
include std/net/url.e

include std/pretty.e

include edbi/defs.e

-- Local Variables

map db_handles = map:new(1)

enum DBH_ERROR_CODE, DBH_ERROR_MESSAGE, DBH_AFFECTED_ROWS

-- Local Constants
constant P = C_POINTER, I = C_INT
constant
	PG_TYPE_BOOL				 = 16,
	--PG_TYPE_BYTEA				   = 17,
	--PG_TYPE_CHAR				   = 18,
	--PG_TYPE_NAME				   = 19,
	PG_TYPE_INT8				 = 20,
	PG_TYPE_INT2				 = 21,
	--PG_TYPE_INT2VECTOR		   = 22,
	PG_TYPE_INT4				 = 23,
	--PG_TYPE_REGPROC			   = 24,
	--PG_TYPE_TEXT				   = 25,
	--PG_TYPE_OID				   = 26,
	--PG_TYPE_TID				   = 27,
	--PG_TYPE_XID				   = 28,
	--PG_TYPE_CID				   = 29,
	--PG_TYPE_OIDVECTOR			   = 30,
	--PG_TYPE_SET				   = 32,
	--PG_TYPE_CHAR2				   = 409,
	--PG_TYPE_CHAR4				   = 410,
	--PG_TYPE_CHAR8				   = 411,
	--PG_TYPE_POINT				   = 600,
	--PG_TYPE_LSEG				   = 601,
	--PG_TYPE_PATH				   = 602,
	--PG_TYPE_BOX				   = 603,
	--PG_TYPE_POLYGON			   = 604,
	--PG_TYPE_FILENAME			   = 605,
	PG_TYPE_FLOAT4				 = 700,
	PG_TYPE_FLOAT8				 = 701,
	--PG_TYPE_ABSTIME			   = 702,
	--PG_TYPE_RELTIME			   = 703,
	--PG_TYPE_TINTERVAL			   = 704,
	--PG_TYPE_UNKNOWN			   = 705,
	PG_TYPE_MONEY				 = 790,
	PG_TYPE_OIDINT2				 = 810,
	PG_TYPE_OIDINT4				 = 910,
	--PG_TYPE_OIDNAME			   = 911,
	--PG_TYPE_BPCHAR			   = 1042,
	--PG_TYPE_VARCHAR			   = 1043,
	PG_TYPE_DATE				 = 1082,
	PG_TYPE_TIME				 = 1083,  -- w/o timezone
	--PG_TYPE_TIMETZ			   = 1266,	-- with timezone
	PG_TYPE_TIMESTAMP			 = 1114,  -- w/o timezone
	--PG_TYPE_TIMESTAMPTZ		   = 1184,	-- with timezone
	PG_TYPE_NUMERIC				 = 1700,
	--CONNECTION_OK				   = 0,
	--CONNECTION_BAD			   = 1,
	--CONNECTION_STARTED		   = 2,
	--CONNECTION_MADE			   = 3,
	--CONNECTION_AWAITING_RESPONSE = 4,
	--CONNECTION_AUTH_OK		   = 5,
	--CONNECTION_SETENV			   = 6,
	--CONNECTION_SSL_STARTUP	   = 7,
	--CONNECTION_NEEDED			   = 8,
	--PGRES_POLLING_FAILED		   = 0,
	--PGRES_POLLING_READING		   = 1,
	--PGRES_POLLING_WRITING		   = 2,
	--PGRES_POLLING_OK			   = 3,
	--PGRES_POLLING_ACTIVE		   = 4,
	PGRES_EMPTY_QUERY			 = 0,
	PGRES_COMMAND_OK			 = 1,
	PGRES_TUPLES_OK				 = 2,
	PGRES_COPY_OUT				 = 3,
	PGRES_COPY_IN				 = 4,
	PGRES_BAD_RESPONSE		     = 5,
	PGRES_NONFATAL_ERROR		 = 6,
	PGRES_FATAL_ERROR			 = 7
	--PQTRANS_IDLE				   = 0,
	--PQTRANS_ACTIVE			   = 1,
	--PQTRANS_INTRANS			   = 2,
	--PQTRANS_INERROR			   = 3,
	--PQTRANS_UNKNOWN			   = 4,
	--PQERRORS_TERSE			   = 0,
	--PQERRORS_DEFAULT			   = 1,
	--PQERRORS_VERBOSE			   = 2

constant int_types = {
	PG_TYPE_INT2, PG_TYPE_INT4, PG_TYPE_INT8, PG_TYPE_BOOL
}

constant atom_types = {
	PG_TYPE_FLOAT4, PG_TYPE_FLOAT8, PG_TYPE_NUMERIC, PG_TYPE_MONEY,
	PG_TYPE_OIDINT2, PG_TYPE_OIDINT4
}

constant date_types = {
	PG_TYPE_DATE, PG_TYPE_TIME, PG_TYPE_TIMESTAMP
}

constant lib = open_dll({ "pq.dll", "libpq.so", "libpq.dll", "libpq.dylib" })

if lib = 0 then
	crash("Could not find a suitable PostgreSQL shared library")
end if

constant
	hPQconnectdb = define_c_func(lib, "PQconnectdb", { P }, P),
	hPQfinish = define_c_proc(lib, "PQfinish", { P }),
	hPQstatus = define_c_func(lib, "PQstatus", { P }, I),
	hPQerrorMessage = define_c_func(lib, "PQerrorMessage", { P }, P),
	hPQexec = define_c_func(lib, "PQexec", { P, P }, P),
	hPQresultStatus = define_c_func(lib, "PQresultStatus", { P }, I),
	hPQresultErrorMessage = define_c_func(lib, "PQresultErrorMessage", { P }, P),
	hPQclear = define_c_proc(lib, "PQclear", { P }),
	hPQntuples = define_c_func(lib, "PQntuples", { P }, I),
	hPQnfields = define_c_func(lib, "PQnfields", { P }, I),
	hPQfnumber = define_c_func(lib, "PQfnumber", { P, P }, I),
	hPQfname = define_c_func(lib, "PQfname", { P, I }, P),
	hPQftype = define_c_func(lib, "PQftype", { P, I }, I),
	hPQgetisnull = define_c_func(lib, "PQgetisnull", { P, I, I }, I),
	hPQgetvalue = define_c_func(lib, "PQgetvalue", { P, I, I }, I),
	hPQcmdTuples = define_c_func(lib, "PQcmdTuples", { P }, I)

procedure register_connection(atom dbh)
	sequence extra = { 0, "", 0 }

	map:put(db_handles, dbh, extra)
end procedure

procedure unregister_connection(atom dbh)
	map:remove(db_handles, dbh)
end procedure

function get_connection(atom dbh)
	return map:get(db_handles, dbh, 0)
end function

procedure update_connection(atom dbh, sequence extra)
	map:put(db_handles, dbh, extra)
end procedure

public function edbi_open(sequence conn_str)
    object host, user, passwd, db, port--, socket, flags

	conn_str = "pgsql://" & conn_str

	object params = url:parse(conn_str, 0)

	host   = params[URL_HOSTNAME]
	port   = defaulted_value(params[URL_PORT], 0)
	db     = params[URL_PATH][2..$]
	user   = params[URL_USER]
	passwd = params[URL_PASSWORD]
	--socket = map:get(params[URL_QUERY_STRING], "socket", 0)
	--flags  = map:get(params[URL_QUERY_STRING], "flags", 0)
	--socket = 0
	--flags = 0

	params = {}

	if port != 0 then
		params &= sprintf("port=%d ", { port })
	end if
	
	if sequence(host) then
		params &= sprintf("host=%s ", { host })
	end if

	if sequence(user) then
		params &= sprintf("user=%s ", { user })
	end if

	if sequence(passwd) then
		params &= sprintf("password=%s ", { passwd })
	end if

	if sequence(db) then
		params &= sprintf("dbname=%s ", { db })
	end if

	atom pConnectStr = allocate_string(params)
	atom p_res = c_func(hPQconnectdb, { pConnectStr })
	free(pConnectStr)

	register_connection(p_res)

	return p_res
end function

public procedure edbi_close(atom dbh)
	unregister_connection(dbh)

	c_proc(hPQfinish, { dbh })
end procedure

public function edbi_error_code(atom dbh)
	sequence extra = get_connection(dbh)
	return extra[DBH_ERROR_CODE]
end function

public function edbi_error_message(atom dbh)
	sequence extra = get_connection(dbh)
	return extra[DBH_ERROR_MESSAGE]
end function

public function edbi_closeq(atom dbr)
	c_proc(hPQclear, { dbr })
	return 1
end function

public function edbi_execute(atom dbh, sequence sql)
	integer status
	sequence extra
	atom res, pSql

	extra = get_connection(dbh)
	extra[DBH_ERROR_CODE] = 0
	extra[DBH_ERROR_MESSAGE] = ""

	pSql = allocate_string(sql)
	res = c_func(hPQexec, { dbh, pSql })
	free(pSql)

	status = c_func(hPQresultStatus, { res })

	if status = PGRES_TUPLES_OK then
		status = 0
	elsif find(status, { PGRES_EMPTY_QUERY, PGRES_COMMAND_OK,
				PGRES_COPY_OUT, PGRES_COPY_IN })
	then
		atom pVal
		sequence v

		pVal = c_func(hPQcmdTuples, { res })
		v = value(peek_string(pVal))
		if v[1] = GET_SUCCESS then
			status = v[2]
		else
			status = 0
		end if
	else
		extra[DBH_ERROR_MESSAGE] = peek_string(c_func(hPQresultErrorMessage, { res }))

		status = -1
	end if

	edbi_closeq(res)

	extra[DBH_AFFECTED_ROWS] = status
	update_connection(dbh, extra)

	return status
end function

public function edbi_total_changes(atom dbh)
	sequence extras = get_connection(dbh)

	return extras[DBH_AFFECTED_ROWS]
end function

public function edbi_query(atom dbh, sequence sql)
	integer status
	sequence extra, fdata = {}
	atom res, pSql

	extra = get_connection(dbh)
	extra[DBH_AFFECTED_ROWS] = 0
	extra[DBH_ERROR_CODE] = 0
	extra[DBH_ERROR_MESSAGE] = ""

	pSql = allocate_string(sql)
	res = c_func(hPQexec, { dbh, pSql })
	free(pSql)

	status = c_func(hPQresultStatus, { res })

	if status = PGRES_TUPLES_OK then
		-- Do nothing, everything is fine
	elsif find(status, { PGRES_EMPTY_QUERY, PGRES_COMMAND_OK,
				PGRES_COPY_OUT, PGRES_COPY_IN })
	then
		extra[DBH_ERROR_CODE] = 1
		extra[DBH_ERROR_MESSAGE] = "No tuples returned"

		edbi_closeq(res)
		res = 0
	else
		extra[DBH_ERROR_MESSAGE] = peek_string(c_func(hPQresultErrorMessage, { res }))

		edbi_closeq(res)
		res = 0
	end if

	update_connection(dbh, extra)

	if res then
		--integer row_count = c_func(hPQntuples, { res })
		integer col_count = c_func(hPQnfields, { res })
		fdata = repeat(0, col_count)

		for col = 1 to col_count do
			integer    ft = c_func(hPQftype, { res, col - 1 })
			sequence fname = peek_string(c_func(hPQfname, { res, col - 1 }))
			integer ftype = EU_SEQUENCE -- Default is a SEQUENCE

			if find(ft, int_types) then
				ftype = EU_INTEGER
			elsif find(ft, atom_types) then
				ftype = EU_ATOM
			elsif find(ft, date_types) then
				ftype = EU_DATETIME
			end if

			fdata[col] = { fname, ftype }
		end for
	end if

	return { res, fdata }
end function

public function edbi_next(atom dbr, atom row)
	integer row_count = c_func(hPQntuples, { dbr })
	integer col_count = c_func(hPQnfields, { dbr })

	if row > row_count then
		return 0
	end if

	sequence result = repeat(0, col_count)
	for i = 1 to col_count do
		atom  pValue = c_func(hPQgetvalue, { dbr, row - 1, i - 1 })
		result[i] = peek_string(pValue)
	end for

	return result
end function

public function edbi_last_insert_id(atom dbh, sequence seq_name)
	return -1
end function

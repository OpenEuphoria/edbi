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

enum 
	MYSQL_TYPE_DECIMAL=0,
	MYSQL_TYPE_TINY,
	MYSQL_TYPE_SHORT,
	MYSQL_TYPE_LONG,
	MYSQL_TYPE_FLOAT,
	MYSQL_TYPE_DOUBLE,
	MYSQL_TYPE_NULL,
	MYSQL_TYPE_TIMESTAMP,
	MYSQL_TYPE_LONGLONG,
	MYSQL_TYPE_INT24,
	MYSQL_TYPE_DATE,
	MYSQL_TYPE_TIME,
	MYSQL_TYPE_DATETIME,
	MYSQL_TYPE_YEAR,
	MYSQL_TYPE_NEWDATE,
	MYSQL_TYPE_VARCHAR,
	MYSQL_TYPE_BIT,
	MYSQL_TYPE_NEWDECIMAL=246,
	MYSQL_TYPE_ENUM=247,
	MYSQL_TYPE_SET=248,
	MYSQL_TYPE_TINY_BLOB=249,
	MYSQL_TYPE_MEDIUM_BLOB=250,
	MYSQL_TYPE_LONG_BLOB=251,
	MYSQL_TYPE_BLOB=252,
	MYSQL_TYPE_VAR_STRING=253,
	MYSQL_TYPE_STRING=254,
	MYSQL_TYPE_GEOMETRY=255

constant lib_mysql = open_dll({
    "/home/openeuph/euweb/libmysqlclient.so.15.0.0", -- stupid hack for openeuphoria.org
    "libmysqlclient.so", 
    "/usr/lib/libmysqlclient.so",
    "/usr/local/lib/libmysqlclient.so",
    "libmysqlclient.dylib",
	"libmysql.dll"
})

if lib_mysql = 0 then
	crash("Could not find a suitable MySQL shared library")
end if

constant
	h_mysql_init = define_c_func(lib_mysql, "mysql_init", {C_POINTER}, C_POINTER),
	h_mysql_real_connect = define_c_func(lib_mysql, "mysql_real_connect", {
		C_POINTER, C_POINTER, C_POINTER, C_POINTER, C_POINTER, C_UINT, C_POINTER,
		C_ULONG}, C_POINTER),
	h_mysql_close = define_c_proc(lib_mysql, "mysql_close", {C_POINTER}),
	h_mysql_error = define_c_func(lib_mysql, "mysql_error", {C_POINTER}, C_POINTER),
	h_mysql_errno = define_c_func(lib_mysql, "mysql_errno", {C_POINTER}, C_INT),
	h_mysql_real_query = define_c_func(lib_mysql, "mysql_real_query", {C_POINTER, C_POINTER,
		C_ULONG}, C_INT),
	h_mysql_field_count = define_c_func(lib_mysql, "mysql_field_count", {C_POINTER}, C_UINT),
	h_mysql_use_result = define_c_func(lib_mysql, "mysql_use_result", {C_POINTER}, C_POINTER),
	h_mysql_free_result = define_c_proc(lib_mysql, "mysql_free_result", {C_POINTER}),
	h_mysql_fetch_row = define_c_func(lib_mysql, "mysql_fetch_row", {C_POINTER}, C_POINTER),
	h_mysql_num_fields = define_c_func(lib_mysql, "mysql_num_fields", {C_POINTER}, C_UINT),
	h_mysql_fetch_lengths = define_c_func(lib_mysql, "mysql_fetch_lengths", {C_POINTER}, C_POINTER),
	h_mysql_insert_id = define_c_func(lib_mysql, "mysql_insert_id", {C_POINTER}, C_ULONG),
	h_mysql_fetch_field_direct = define_c_func(lib_mysql, "mysql_fetch_field_direct", {C_POINTER, C_INT}, C_POINTER),
	h_mysql_affected_rows = define_c_func(lib_mysql, "mysql_affected_rows", {C_POINTER}, C_INT)

integer did_initialize = 0

function mysql_init(atom dbh=0)
	return c_func(h_mysql_init, {dbh})
end function

include std/pretty.e

public function edbi_open(sequence conn_str)
    object host, user, passwd, db, port, socket, flags

	conn_str = "mysql://" & conn_str

	object params = url:parse(conn_str, 0)

	host   = params[URL_HOSTNAME]
	port   = defaulted_value(params[URL_PORT], 0)
	db     = params[URL_PATH][2..$]
	user   = params[URL_USER]
	passwd = params[URL_PASSWORD]
	--socket = map:get(params[URL_QUERY_STRING], "socket", 0)
	--flags  = map:get(params[URL_QUERY_STRING], "flags", 0)
	socket = 0
	flags = 0

	if port = 0 then
		port = 3306
	end if
	
	if sequence(host) then
		host = allocate_string(host)
	end if

	if sequence(user) then
		user = allocate_string(user)
	end if

	if sequence(passwd) then
		passwd = allocate_string(passwd)
	end if

	if sequence(db) then
		db = allocate_string(db)
	end if

	if sequence(socket) then
		socket = allocate_string(socket)
	end if

	atom dbh = mysql_init()
	atom p_mysql = c_func(h_mysql_real_connect, {dbh, host, user, passwd, db, port, socket, flags})

	free({ host, user, passwd, db })
	if socket != 0 then
		free(socket)
	end if

	return p_mysql
end function

public procedure edbi_close(atom dbh)
	c_proc(h_mysql_close, {dbh})
end procedure

public function edbi_error_code(atom dbh)
	return c_func(h_mysql_errno, {dbh})
end function

public function edbi_error_message(atom dbh)
	sequence message = ""
	atom p_error = c_func(h_mysql_error, {dbh})

	if p_error != NULL then
		-- Memory is free'd by MySQL when connection is closed
		message = peek_string(p_error)
	end if

	return message
end function

public function edbi_last_insert_id(atom dbh, sequence seq_name)
	seq_name = seq_name -- not used

	return c_func(h_mysql_insert_id, {dbh})
end function

function mysql_field_count(atom dbh)
	return c_func(h_mysql_field_count, {dbh})
end function

function mysql_use_result(atom dbh)
	return c_func(h_mysql_use_result, {dbh})
end function

-- Matt's second update for 64 bit euphoria compatibility
ifdef BITS32 then 
	constant MYSQL_FIELD_type = 76 
elsedef 
	constant MYSQL_FIELD_type = 112 
end ifdef 

-- Matt's new mysql_fetch_field_direct 
function mysql_fetch_field_direct(atom dbr, integer idx) 
	atom p_f = c_func(h_mysql_fetch_field_direct, { dbr, idx }) 
	sequence name = peek_string(peek_pointer(p_f)) 
	integer typ = peek4u(p_f + MYSQL_FIELD_type) 
	return { name, typ } 
end function 

public procedure edbi_closeq(atom dbr)
	c_proc(h_mysql_free_result, {dbr})
end procedure

function mysql_num_fields(atom dbr)
	return c_func(h_mysql_num_fields, {dbr})
end function

function mysql_fetch_lengths(atom dbr)
	return c_func(h_mysql_fetch_lengths, {dbr})
end function

-- Extra routine needed for Matt's update to edbi_next
function peek_longu( object ptr ) 
    ifdef LONG32 then 
        return peek4u( ptr ) 
    elsedef 
        return peek8u( ptr ) 
    end ifdef 
end function 

-- Matt's update for edbi_next to work with both 32 and 64 bit euphoria 
public function edbi_next(atom dbr, atom row) 
	atom p_lengths, p_row = c_func(h_mysql_fetch_row, {dbr}) 
	integer field_count 
	object data = {}, tmp 
 
	row = row -- not used 
 
	if p_row = 0 then 
		return 0 
	end if 
 
	p_lengths = mysql_fetch_lengths(dbr) 
	field_count = mysql_num_fields(dbr) 
 
        integer row_offset = 0 
        integer len_offset = 0 
	for i = 0 to (field_count - 1) * sizeof( C_POINTER ) by sizeof( C_POINTER ) do 
		data &= {peek({peek_pointer(p_row + row_offset), peek_longu(p_lengths + len_offset)})} 
                row_offset += sizeof( C_POINTER ) 
                len_offset += sizeof( C_LONG ) 
	end for 
 
	return data 
end function 

public function edbi_execute(atom dbh, sequence sql)
	atom p_sql = allocate_string(sql)
	integer result = c_func(h_mysql_real_query, {dbh, p_sql, length(sql)})
	free(p_sql)

	return result
end function

public function edbi_total_changes(atom dbh)
	return c_func(h_mysql_affected_rows, { dbh })
end function

public function edbi_query(atom dbh, sequence sql)
	integer q_result = edbi_execute(dbh, sql)
	if not q_result = 0 then
		return 0
	end if
	
	atom dbr = mysql_use_result(dbh)
	sequence fdata = repeat(0, mysql_num_fields(dbr))

	for i = 1 to length(fdata) do
		object f = mysql_fetch_field_direct(dbr, i - 1)
		integer ftype = EU_SEQUENCE -- Default is a SEQUENCE

		switch f[2] do
			case MYSQL_TYPE_DECIMAL, MYSQL_TYPE_FLOAT, MYSQL_TYPE_DOUBLE, MYSQL_TYPE_NEWDECIMAL then
				ftype = EU_ATOM

			case MYSQL_TYPE_TINY, MYSQL_TYPE_SHORT, MYSQL_TYPE_LONG, MYSQL_TYPE_LONGLONG,
				MYSQL_TYPE_INT24
			then
				ftype = EU_INTEGER

			case MYSQL_TYPE_TIMESTAMP, MYSQL_TYPE_DATE, MYSQL_TYPE_TIME, MYSQL_TYPE_DATETIME then
				ftype = EU_DATETIME
		end switch

		fdata[i] = { f[1], ftype }
	end for

	return { dbr, fdata }
end function


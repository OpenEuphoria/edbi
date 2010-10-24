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

include std/dll.e
include std/error.e
include std/get.e
include std/machine.e
include std/map.e
include std/search.e
include std/text.e
include std/net/url.e
include std/eumem.e

-- You must have EuSQL installed to use this driver. It should be available from eu.cfg.
include eusql.e as eusql

include edbi/defs.e

enum DB_NAME, DB_ERR
enum Q_DB_ID, Q_ROW, Q_ROW_COUNT, Q_DATA

public function edbi_open(sequence conn_str)
	puts(1, "edbi_open\n")
	object o
	atom dbh = eumem:malloc()
	puts(1, "eumem:malloc()\n")
	o = open_db(conn_str)
	puts(1, "open_db\n")
	if atom(o) then
		puts(1, "create_db\n")
		o = create_db(conn_str)
		puts(1, "done with create_db\n")
		if atom(o) then
			printf(1, "Couldn't be opened or created\n", {})
			return 0
		end if
	end if

	ram_space[dbh] = { conn_str, 0 }

	printf(1, "returning from edbi_open: %d\n", { dbh })

	return dbh
end function

public procedure edbi_close(atom dbh)
	close_db(ram_space[dbh][DB_NAME])

	eumem:free(dbh)
end procedure

public function edbi_error_code(atom dbh)
	return ram_space[dbh][DB_ERR]
end function

public function edbi_error_message(atom dbh)
	return get_sql_err(ram_space[dbh][DB_ERR])
end function

public function edbi_last_insert_id(atom dbh)
-- 	return c_func(h_mysql_insert_id, {dbh})
	return 0
end function

public procedure edbi_closeq(atom dbr)
	eumem:free(dbr)
end procedure

public function edbi_next(atom dbr, atom row)
	row = row -- not used

	ram_space[dbr][Q_ROW] += 1
	if ram_space[dbr][Q_ROW] > ram_space[dbr][Q_ROW_COUNT] then
		return 0
	end if

	return ram_space[dbr][Q_DATA][ram_space[dbr][Q_ROW]]
end function

public function edbi_execute(atom dbh, sequence sql)
	eusql:select_db(ram_space[dbh][DB_NAME])
	return atom(run_sql(sql))
end function

public function edbi_total_changes(atom dbh)
-- 	return c_func(h_mysql_affected_rows, { dbh })
	return 0
end function

public function edbi_query(atom dbh, sequence sql)
	eusql:select_db(ram_space[dbh][DB_NAME])
	object q_result = run_sql(sql)

	if atom(q_result) then
		return q_result
	end if

	-- 1st element is a list of names:
	-- { "NAME", "AGE", "DOB" }
	--
	-- We need to turn it into:
	-- { { "NAME", TYPE }, { "AGE", TYPE }, { "DOB", TYPE } }
	--
	for i = 1 to length(q_result[1]) do
		q_result[1][i] = { q_result[1][i], EU_NATIVE } -- EU_NATIVE = Native format already
	end for

	atom dbr = eumem:malloc()
 	-- { database handle, current row, row count, row data }
	ram_space[dbr] = { dbh, 0, length(q_result[1]), q_result[2] }

	return { dbr, q_result[1] } -- result handle, result definition
end function


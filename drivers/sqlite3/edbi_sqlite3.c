/*
--
-- Copyright (C) 2009 by Jeremy Cowgar <jeremy@cowgar.com>
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
*/

#include <euphoria.h>
#include "sqlite3.h"

#include "euinit.h"
#include "edbi.h"

/*
Functions to expose:

  X open
  X close
  X get_error_code
  X get_error_message
  X execute
  X query
  X next
  X closeq
  * is_empty
  X last_insert_id
  X total_changes
*/

object __cdecl edbi_open(object conn_str)
{
	char *c_conn_str;
    sqlite3 *db;
    int result;

    LibMain(0, 1, 0);

	c_conn_str = EMalloc(SEQ_PTR(conn_str)->length + 1);
	MakeCString(c_conn_str, conn_str, SEQ_PTR(conn_str)->length + 1);

	result = sqlite3_open(c_conn_str, &db);

	EFree(c_conn_str);

    return db;
}

void __cdecl edbi_close(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;
    if (db != 0)
        sqlite3_close(db);
}

object __cdecl edbi_error_code(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;

    return sqlite3_errcode(db);
}

object __cdecl edbi_error_message(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;
    char *msg = sqlite3_errmsg(db);

    return NewString(msg);
}

object __cdecl edbi_execute(object dbh, object sql)
{
    sqlite3 *db = (sqlite3 *) dbh;
	char *c_sql;
    int result;

	c_sql = EMalloc(SEQ_PTR(sql)->length + 1);
	MakeCString(c_sql, sql, SEQ_PTR(sql)->length + 1);

    result = sqlite3_exec(db, c_sql, 0, 0, 0);
	
	EFree(c_sql);

    return result;
}

object __cdecl edbi_last_insert_id(object dbh, object seq_name)
{
    sqlite3 *db = (sqlite3 *) dbh;

    return sqlite3_last_insert_rowid(db);
}

object __cdecl edbi_total_changes(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;

    return sqlite3_total_changes(db);
}

object __cdecl edbi_query(object dbh, object sql)
{
    sqlite3 *db = (sqlite3 *) dbh;
    sqlite3_stmt *stmt = 0;

	char *c_sql = EMalloc(SEQ_PTR(sql)->length + 1);
	MakeCString(c_sql, sql, SEQ_PTR(sql)->length + 1);

    int status = sqlite3_prepare(db, c_sql, -1, &stmt, 0);

    EFree(c_sql);

	s1_ptr result = NewS1(2);
    result->base[1] = stmt;

    int i, cols = sqlite3_column_count(stmt);
    s1_ptr col_data = NewS1(cols);

    for (i=0; i < cols; i++)
    {
        char *typ = sqlite3_column_decltype(stmt, i);
        s1_ptr col = NewS1(2);

        col->base[1] = NewString(sqlite3_column_name(stmt, i));

        if (strnicmp(typ, "numeric", 7) == 0 ||
            strnicmp(typ, "decimal", 7) == 0)
        {
            col->base[2] = EU_ATOM;
        }
        else if (strnicmp(typ, "integer", 7) == 0)
        {
            col->base[2] = EU_INTEGER;
        }
        else if (strnicmp(typ, "date", 4) == 0)
        {
            col->base[2] = EU_DATETIME;
        }
        else
        {
            col->base[2] = EU_SEQUENCE;
        }

        col_data->base[i+1] = MAKE_SEQ(col);
    }

    result->base[2] = MAKE_SEQ(col_data);

    return MAKE_SEQ(result);
}

object __cdecl edbi_next(object dbr, object row)
{
    sqlite3_stmt *stmt = (sqlite3 *) dbr;
    int result = sqlite3_step(stmt);

    if (result == SQLITE_ROW) {
        int i, cols = sqlite3_column_count(stmt);
        s1_ptr s = NewS1(cols);

        for (i=0; i < cols; i++) {
            s->base[i + 1] = NewString(sqlite3_column_text(dbr, i));
        }

        return MAKE_SEQ(s);
    }

    return result;
}

void __cdecl edbi_closeq(object dbr)
{
    sqlite3_stmt *stmt = (sqlite3 *) dbr;
    sqlite3_finalize(stmt);
}

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

#ifndef __MINGW32__
int strnicmp(const char *s1, const char *s2, size_t len)
{ 
    /* Yes, Virginia, it had better be unsigned */
    unsigned char c1, c2;

    if (!len)
        return 0;
    if (s1 == NULL)
        return -1;
    if (s2 == NULL)
        return 1;

    do {
        c1 = *s1++;
        c2 = *s2++;
        if (!c1 || !c2)
            break;
        if (c1 == c2)
            continue;
        c1 = tolower(c1);
        c2 = tolower(c2);
        if (c1 != c2)
            break;
    } while (--len);
    return (int)c1 - (int)c2;
}
#endif

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

object EXPORT edbi_open(object conn_str)
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

void EXPORT edbi_close(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;
    if (db != 0)
        sqlite3_close(db);
}

object EXPORT edbi_error_code(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;

    return sqlite3_errcode(db);
}

object EXPORT edbi_error_message(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;
    char *msg = sqlite3_errmsg(db);

    return NewString(msg);
}

object EXPORT edbi_execute(object dbh, object sql)
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

object EXPORT edbi_last_insert_id(object dbh, object seq_name)
{
    sqlite3 *db = (sqlite3 *) dbh;

    return sqlite3_last_insert_rowid(db);
}

object EXPORT edbi_total_changes(object dbh)
{
    sqlite3 *db = (sqlite3 *) dbh;

    return sqlite3_total_changes(db);
}

object EXPORT edbi_query(object dbh, object sql)
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

        if (typ == NULL)
        {
            col->base[2] = EU_NATIVE;
        }
        else if (strnicmp(typ, "numeric", 7) == 0 ||
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

object EXPORT edbi_next(object dbr, object row)
{
    sqlite3_stmt *stmt = (sqlite3 *) dbr;
    int result = sqlite3_step(stmt);

    if (result == SQLITE_ROW) {
        int i, cols = sqlite3_column_count(stmt);
        s1_ptr s = NewS1(cols);

        for (i=0; i < cols; i++) {
			char *colTxt = sqlite3_column_text(dbr, i);
			if (colTxt == NULL) {
				s->base[i + 1] = NewString("");
			} else {
	            s->base[i + 1] = NewString(sqlite3_column_text(dbr, i));
			}
        }

        return MAKE_SEQ(s);
    }

    return result;
}

void EXPORT edbi_closeq(object dbr)
{
    sqlite3_stmt *stmt = (sqlite3 *) dbr;
    sqlite3_finalize(stmt);
}

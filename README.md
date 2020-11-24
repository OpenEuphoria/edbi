# EDBI

## Overview

EDBI allows the programmer to use any supporting database with a unified database interface. Database drivers are loaded dynamically and can be written for any database server or client. Multiple database connections can be managed at the same time across multiple drivers. To use a different database server or driver, simply use the correct connection string. For example

    edbi:open("sqlite3://people.db")
    edbi:open("mysql://localhost?dbname=people")
    edbi:open("pgsql://localhost?dbname=people")

EDBI automatically maps database values and types into Euphoria native types. For instance, a VARCHAR comes back as a sequence, a NUMERIC or DECIMAL as an atom, an INTEGER as an integer, a DATE, TIME, DATETIME or TIMESTAMP as a datetime, etc...

Querying EDBI allows the use of Euphoria types directly as well

    edbi:query("SELECT * FROM people WHERE zip=%d AND dob < %D", { 30293, datetime:subtract(datetime:new(), 18, YEARS) })

## Getting EDBI

EDBI was originally hosted on BitBucket: http://bitbucket.org/jcowgar/edbi

You can read more about EDBI at http://jeremy.cowgar.com/edbi/
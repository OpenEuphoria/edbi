CC     = gcc
CFLAGS =  -DEFree=free -DEMalloc=malloc -DERealloc=realloc -fomit-frame-pointer -fPIC -c -w -fsigned-char -O3 -mno-cygwin \
	-mwindows -IC:/Development/Projects/Euphoria/include -I.. -DESIMPLE_MALLOC
LINKER = gcc

EDBI_SQLITE3_SOURCES = \
	sqlite3.c \
	euinit.c \
	edbi_sqlite3.c 

EDBI_SQLITE3_OBJECTS = \
	sqlite3.o \
	euinit.o \
	edbi_sqlite3.o 

edbi_sqlite3.dll: $(EDBI_SQLITE3_OBJECTS)
	$(LINKER) -mwindows -shared -o edbi_sqlite3.dll $(EDBI_SQLITE3_OBJECTS) $(LFLAGS) \
    	c:/Development/Projects/euphoria/bin/eu.a -lws2_32

.PHONY: clean clean-all rebuild

clean:
	rm -rf edbi_sqlite3.dll $(EDBI_SQLITE3_OBJECTS)

rebuild: clean edbi_sqlite3.dll

%.o: %.c
	$(CC) $(CFLAGS) $*.c -o $*.o

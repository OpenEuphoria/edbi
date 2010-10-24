CC     = gcc
CFLAGS = -DEFree=free -DEMalloc=malloc -DERealloc=realloc -fomit-frame-pointer -fPIC \
	-w -fsigned-char -O3 -I$(EUDIR)/include -I.. -DESIMPLE_MALLOC
LINKER = gcc
DLLNAME = edbi_sqlite3.so

EDBI_SQLITE3_SOURCES = \
	sqlite3.c \
	euinit.c \
	edbi_sqlite3.c 

EDBI_SQLITE3_OBJECTS = \
	sqlite3.o \
	euinit.o \
	edbi_sqlite3.o 

$(DLLNAME): $(EDBI_SQLITE3_OBJECTS)
	$(LINKER) -shared -o $(DLLNAME) $(EDBI_SQLITE3_OBJECTS) $(LFLAGS) \
    	$(EUDIR)/bin/eu.a

.PHONY: clean clean-all rebuild

clean:
	rm -rf $(DLLNAME) $(EDBI_SQLITE3_OBJECTS)

rebuild: clean $(DLLNAME)

%.o: %.c
	$(CC) -c $(CFLAGS) $*.c -o $*.o

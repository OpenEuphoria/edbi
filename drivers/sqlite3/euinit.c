/*
--
-- Copyright (C) 2009,2010 by Jeremy Cowgar <jeremy@cowgar.com>
--
-- This file is part of euiup3.
--
-- euiup3 is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as
-- published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- euiup3 is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with euiup3.  If not, see <http://www.gnu.org/licenses/>.
--
*/

#include <time.h>
#include <unistd.h>
#include <euphoria.h>

#include "euinit.h"

int Argc;
char **Argv;
unsigned default_heap;
int iupwin_dll_hinstance;
#ifdef __MINGW32__
__declspec(dllimport) unsigned __stdcall GetProcessHeap(void);
#endif
unsigned long *peek4_addr;
unsigned char *poke_addr;
unsigned short *poke2_addr;
unsigned long *poke4_addr;
struct d temp_d;
double temp_dbl;
char *stack_base;
int total_stack_size = 262144;
unsigned char ** _02;
object _0switches;

int Initialized = 0;


struct routine_list _00[] = {
  {"", 0, 999999999, 0, 0, 0, 0}
};

struct ns_list _01[] = {
  {"", 0, 999999999, 0}
};

void EuInit()
{
	if (Initialized == 1)
		return;

	Initialized = 1;
    Argc = 0;
    #ifdef __MINGW32__
        default_heap = GetProcessHeap();
    #endif

    _02 = (unsigned char**) malloc(4 * 2);
    _02[0] = (unsigned char*) malloc(4);
    _02[0][0] = 1;
    _02[1] = "\x01\x02";

    #ifdef CLK_TCK
        eu_startup(_00, _01, _02, (int)CLOCKS_PER_SEC, (int)CLK_TCK);
    #else
        eu_startup(_00, _01, _02, (int)CLOCKS_PER_SEC, (int)sysconf(_SC_CLK_TCK));
    #endif

    _0switches = MAKE_SEQ(NewS1(0));
}

int EXPORT LibMain(int hDLL, int Reason, void *Reserved)
{
    if (Reason == 1)
		EuInit();
    return 1;
}


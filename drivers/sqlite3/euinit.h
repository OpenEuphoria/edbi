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

extern int Initialized;

extern int Argc;
extern char **Argv;
extern unsigned long *peek4_addr;
extern unsigned char *poke_addr;
extern unsigned short *poke2_addr;
extern unsigned long *poke4_addr;
extern struct d temp_d;
extern double temp_dbl;
extern char *stack_base;
extern int total_stack_size;

extern struct routine_list _00[];
extern unsigned char ** _02;
extern object _0switches;
extern struct ns_list _01[];
extern int TraceOn;
extern object_ptr rhs_slice_target;
extern s1_ptr *assign_slice_seq;
extern object last_r_file_no;
extern void *last_r_file_ptr;
extern int in_from_keyb;
extern void *xstdin;
extern struct tcb *tcb;
extern int current_task;
extern int insert_pos;
extern void *winInstance;


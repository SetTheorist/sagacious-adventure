DMD=dmd -g
GCC=gcc -g

sagadv: creature.d item.d main.d map.d myio.o path.d priority_queue.d rational_lib.d rng.d terminal.d ui.d util.d libsdl.a
	${DMD} -ofsagadv $^

#%.o : %.d
#	${DMD} -c $< -of$@

.c.o:
	${GCC} -c $< -o$@


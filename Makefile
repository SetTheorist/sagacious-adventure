

sagadv: creature.d item.d main.d map.d myio.o path.d priority_queue.d rational_lib.d rng.d terminal.d ui.d util.d
	dmd -ofsagadv $^

#%.o : %.d
#	dmd -c $< -of$@

.c.o:
	gcc -c $< -o$@


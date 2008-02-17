CFLAGS = -g -O3 -W -Wall -Wcast-qual -Wdeclaration-after-statement -Wpointer-arith -Wredundant-decls
CC = gcc

all: pciaccess testefac sum1 softsum1

pciaccess: pciaccess.c
	$(CC) $(CFLAGS) -o $@ $^ -lpci -lz

testefac: testefac.c libefac.c
	$(CC) $(CFLAGS) -o $@ $^ -lpci -lz

sum1: sum1.c libefac.c
	$(CC) $(CFLAGS) -o $@ $^ -lpci -lz

softsum1: sum1.c libsoftefac.c
	$(CC) $(CFLAGS) -DSOFT -o $@ $^

clean:
	rm -f pciaccess testefac sum1 softsum1

.PHONY: all clean

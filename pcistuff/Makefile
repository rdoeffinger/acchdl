CFLAGS = -g -O3 -W -Wall
CC = gcc

all: pciaccess testefac

pciaccess: pciaccess.c
	$(CC) $(CFLAGS) -o $@ $< -lpci -lz

testefac: testefac.c libefac.c
	$(CC) $(CFLAGS) -o $@ $< -lpci -lz

clean:
	rm -f pciaccess testefac

.PHONY: all clean

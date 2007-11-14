CFLAGS = -g -O3 -Wall
CC = gcc

all: pciaccess

pciaccess: pciaccess.c
	$(CC) $(CFLAGS) -o $@ $< -lpci -lz

clean:
	rm -f pciaccess

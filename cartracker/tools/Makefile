
CC=gcc
CFLAGS+=-O3

all: send-car-position

send-car-position: src/send-car-position.c
	$(CC) -o $@ $< $(CFLAGS)


tidy:
	rm -f *.o

clean: tidy
	rm -f send-car-position

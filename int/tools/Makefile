
CC=gcc
CFLAGS+=-O3

all: int-sender int-receiver

int-sender: src/int-sender.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

int-receiver: src/int-receiver.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)


tidy:
	rm -f *.o

clean: tidy
	rm -f int-sender int-receiver

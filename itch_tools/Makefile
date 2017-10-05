
CC=gcc
CFLAGS=-O3 -Ithird-party/libtrading/include

all: receiver replay parse_log generate_mold_messages send_mold_messages monitor_udp

replay: src/replay.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

generate_mold_messages: src/generate_mold_messages.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

send_mold_messages: src/send_mold_messages.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

receiver: src/receiver.c src/common.c
	$(CC) -o $@ $< -lm $(CFLAGS)

monitor_udp: src/monitor_udp.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

parse_log: src/parse_log.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

clean:
	rm -f sender receiver replay parse_log generate_mold_messages send_mold_messages monitor_udp

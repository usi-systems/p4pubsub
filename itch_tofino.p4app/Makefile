

all: sender receiver replay parse_log

sender: src/sender.c
	gcc -Ithird-party/libtrading/include -o $@ $<

replay: src/replay.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

receiver: src/receiver.c
	gcc -Ithird-party/libtrading/include -o $@ $<

parse_log: src/parse_log.c
	gcc -o $@ $<

clean:
	rm -f sender receiver replay



all: sender receiver replay parse_log generate_mold_messages send_mold_messages

sender: src/sender.c
	gcc -Ithird-party/libtrading/include -o $@ $<

replay: src/replay.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

generate_mold_messages: src/generate_mold_messages.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

send_mold_messages: src/send_mold_messages.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

receiver: src/receiver.c
	gcc -Ithird-party/libtrading/include -o $@ $<

parse_log: src/parse_log.c
	gcc -o $@ $<

clean:
	rm -f sender receiver replay parse_log

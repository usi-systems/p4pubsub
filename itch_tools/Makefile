

all: receiver replay parse_log generate_mold_messages send_mold_messages monitor_udp

replay: src/replay.c src/common.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

generate_mold_messages: src/generate_mold_messages.c src/common.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

send_mold_messages: src/send_mold_messages.c src/common.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

receiver: src/receiver.c src/common.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

monitor_udp: src/monitor_udp.c src/common.c
	gcc -O2 -Ithird-party/libtrading/include -o $@ $<

parse_log: src/parse_log.c src/common.c
	gcc -Ithird-party/libtrading/include -o $@ $<

clean:
	rm -f sender receiver replay parse_log generate_mold_messages send_mold_messages monitor_udp

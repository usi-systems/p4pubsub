

all: sender receiver

sender: src/sender.c
	gcc -Ithird-party/libtrading/include -o $@ $<

receiver: src/receiver.c
	gcc -Ithird-party/libtrading/include -o $@ $<

clean:
	rm -f sender receiver

CC=gcc
CFLAGS+=-O2 -Ilibrdkafka_install/include

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(shell dirname $(mkfile_path))

.PHONY: librdkafka tidy clean

all: netkafka_hooks.so

librdkafka:
	git submodule update --init --recursive
	cd ../third-party/librdkafka && ./configure --prefix=$(current_dir)/librdkafka_install
	cd ../third-party/librdkafka && PREFIX=$(current_dir)/librdkafka_install make -j2
	cd ../third-party/librdkafka && PREFIX=$(current_dir)/librdkafka_install make install
	$(CC) -g -O2 -fPIC -Wall -Wsign-compare -Wfloat-equal -Wpointer-arith -Wcast-align  \
	     		-I../third-party/librdkafka/src \
			-L./librdkafka_install/lib \
			../third-party/librdkafka/examples/rdkafka_performance.c \
			-lrdkafka -lpthread -lz -lcrypto -lssl -lsasl2 -lrt -ldl \
			-o rdkafka_performance



libnetkafka.o: src/libnetkafka.c
	$(CC) -c -fPIC -o $@ $< $(CFLAGS)

netkafka_client: libnetkafka.o src/netkafka_client.c
	$(CC) -o $@ $< $(CFLAGS)

netkafka_hooks.so: libnetkafka.o src/netkafka_hooks.c
	$(CC) -Wall -fPIC -shared libnetkafka.o src/netkafka_hooks.c -o netkafka_hooks.so -ldl $(CFLAGS)

tidy:
	rm -f *.o

clean: tidy
	rm -rf rdkafka_performance librdkafka_install *.so 

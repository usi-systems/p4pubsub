
CC=gcc
CFLAGS+=-O3 -Ithird-party/libtrading/include

all: receiver replay parse_log generate_mold_messages send_mold_messages monitor_udp multi_receiver udp_forward mem_send_mold_messages

replay: src/replay.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

generate_mold_messages: src/generate_mold_messages.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

send_mold_messages: src/send_mold_messages.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

mem_send_mold_messages: src/mem_send_mold_messages.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

receiver: src/receiver.c src/common.c
	$(CC) -o $@ $< -lm $(CFLAGS)

monitor_udp: src/monitor_udp.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)

pipe.o: src/pipe.c
	$(CC) -std=c99 -c -o $@ $< $(CFLAGS)


multi_receiver: src/multi_receiver.c pipe.o src/common.c
	$(CC) -o $@ pipe.o $< -lm -lpthread $(CFLAGS)


parse_log: src/parse_log.c src/common.c
	$(CC) -o $@ $< $(CFLAGS)


LIBLFDS_DIR=third-party/liblfds/liblfds/liblfds7.1.0/liblfds710
LIBLFDS_SRC_DIR=$(LIBLFDS_DIR)/src
LIBLFDS_OBJ_DIR=$(LIBLFDS_DIR)/obj

LIBLFDS_QUEUE_OBJ=$(LIBLFDS_OBJ_DIR)/lfds710_queue_bounded_manyproducer_manyconsumer_cleanup.o \
$(LIBLFDS_OBJ_DIR)/lfds710_queue_bounded_manyproducer_manyconsumer_dequeue.o \
$(LIBLFDS_OBJ_DIR)/lfds710_queue_bounded_manyproducer_manyconsumer_enqueue.o \
$(LIBLFDS_OBJ_DIR)/lfds710_queue_bounded_manyproducer_manyconsumer_init.o \
$(LIBLFDS_OBJ_DIR)/lfds710_queue_bounded_manyproducer_manyconsumer_query.o \
$(LIBLFDS_OBJ_DIR)/lfds710_misc_globals.o \
$(LIBLFDS_OBJ_DIR)/lfds710_misc_internal_backoff_init.o \
$(LIBLFDS_OBJ_DIR)/lfds710_misc_query.o

$(LIBLFDS_OBJ_DIR)/%.o: $(LIBLFDS_SRC_DIR)/lfds710_queue_bounded_manyproducer_manyconsumer/%.c
	cd $(LIBLFDS_DIR)/build/gcc_gnumake && make

udp_forward: src/udp_forward.c $(LIBLFDS_QUEUE_OBJ)
	$(CC) -o $@ $< $(LIBLFDS_QUEUE_OBJ) -I$(LIBLFDS_DIR)/inc -lpthread $(CFLAGS)

send_udp_pkts: src/send_udp_pkts.c
	$(CC) -o $@ $< $(CFLAGS)

tidy:
	rm -f pipe.o

clean: tidy
	rm -f sender receiver replay parse_log generate_mold_messages send_mold_messages monitor_udp udp_forward mem_send_mold_messages


#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
#include <time.h>
#include <librdkafka/rdkafka.h>
#include "netkafka.h"
#include <assert.h>


rd_kafka_t* (*o_rd_kafka_new)(rd_kafka_type_t, rd_kafka_conf_t*, char*, size_t) = NULL;
int (*o_rd_kafka_brokers_add)(rd_kafka_t*, const char*) = NULL;
ssize_t (*o_rd_kafka_consume_batch)(rd_kafka_topic_t*, int32_t, int, rd_kafka_message_t**, size_t) = NULL;
int (*o_rd_kafka_poll)(rd_kafka_t*, int) = NULL;
rd_kafka_topic_t* (*o_rd_kafka_topic_new)(rd_kafka_t*, const char*, rd_kafka_topic_conf_t*) = NULL;
rd_kafka_queue_t* (*o_rd_kafka_queue_new)(rd_kafka_t*) = NULL;
int (*o_rd_kafka_consume_start_queue)(rd_kafka_topic_t*, int32_t, int64_t, rd_kafka_queue_t*) = NULL;
int (*o_rd_kafka_consume_callback_queue)(rd_kafka_queue_t*, int, void (rd_kafka_message_t*, void*), void*) = NULL;
int (*o_rd_kafka_produce)(rd_kafka_topic_t*, int32_t, int, void*, size_t, const void*, size_t, void*) = NULL;
void (*o_rd_kafka_conf_set_dr_msg_cb)(rd_kafka_conf_t*,
                                  void (*dr_msg_cb) (rd_kafka_t*, const rd_kafka_message_t*, void*)) = NULL;


rd_kafka_message_t tmp_msg;
rd_kafka_t *nk_rk;
char tmp_payload[1024];
unsigned tmp_offset = 0;
struct netkafka_client *nk_cl = NULL;
uint32_t nk_topic_tag;
void (*nk_dr_msg_cb)(rd_kafka_t*, const rd_kafka_message_t*, void*) = NULL;

// we need to know whether our hooks are for consumer or producer mode
rd_kafka_type_t hook_mode;

int rd_kafka_produce(rd_kafka_topic_t *rkt, int32_t partition, int msgflags, void *payload,
        size_t len, const void *key, size_t keylen, void *msg_opaque) {

    if (o_rd_kafka_produce == NULL) {
        o_rd_kafka_produce = dlsym(RTLD_NEXT, "rd_kafka_produce");
        if (o_rd_kafka_produce == NULL) {
            printf("Could not find next rd_kafka_produce() function occurrence");
            return -1;
        }
    }

    assert(nk_cl != NULL);
    netkafka_produce(nk_cl, nk_topic_tag, payload, len);

    nk_dr_msg_cb(nk_rk, &tmp_msg, NULL);

    return o_rd_kafka_produce(rkt, partition, msgflags, payload, len, key, keylen, msg_opaque);
}

void rd_kafka_conf_set_dr_msg_cb(rd_kafka_conf_t *conf,
                                  void (*dr_msg_cb) (rd_kafka_t *rk,
                                                     const rd_kafka_message_t *
                                                     rkmessage,
                                                     void *opaque)) {
    o_rd_kafka_conf_set_dr_msg_cb = dlsym(RTLD_NEXT, "rd_kafka_conf_set_dr_msg_cb");
    if (o_rd_kafka_conf_set_dr_msg_cb == NULL) {
        printf("Could not find next rd_kafka_conf_set_dr_msg_cb() function occurrence");
        return;
    }
    printf("rd_kafka_conf_set_dr_msg_cb() call intercepted\n");

    nk_dr_msg_cb = dr_msg_cb;

    //return o_rd_kafka_conf_set_dr_msg_cb(conf, dr_msg_cb);
}

unsigned last_seq = 0;

int rd_kafka_consume_callback_queue(rd_kafka_queue_t *rkqu, int timeout_ms,
				     void (*consume_cb)(rd_kafka_message_t*, void*), void *opaque) {
    //o_rd_kafka_consume_callback_queue = dlsym(RTLD_NEXT, "rd_kafka_consume_callback_queue");
    //if (o_rd_kafka_consume_callback_queue == NULL) {
    //    printf("Could not find next rd_kafka_consume_callback_queue() function occurrence");
    //    return 0;
    //}
    //printf("rd_kafka_consume_callback_queue() call intercepted\n");
    //return o_rd_kafka_consume_callback_queue(rkqu, timeout_ms, consume_cb, opaque);

    assert(nk_cl != NULL);
    if (netkafka_consume(nk_cl, tmp_msg.payload, &tmp_msg.len) < 0) {
        printf("Error consuming\n");
        return 0;
    }

    char *d = tmp_msg.payload;
    unsigned seq;
    if ('0' <= d[0] && d[0] <= '9' && sscanf(d, "%d", &seq) == 1) {
        if (last_seq > 0 && last_seq+1 != seq) {
            printf("ERROR: received bad seq number %d (expected %d)\n", seq, last_seq);
        }
        last_seq = seq;
    }

    tmp_msg.offset = tmp_offset++;

    consume_cb(&tmp_msg, NULL);
    return 0;
}

//int rd_kafka_consume_start_queue(rd_kafka_topic_t *rkt, int32_t partition,
//				  int64_t offset, rd_kafka_queue_t *rkqu) {
//    o_rd_kafka_consume_start_queue = dlsym(RTLD_NEXT, "rd_kafka_consume_start_queue");
//    if (o_rd_kafka_consume_start_queue == NULL) {
//        printf("Could not find next rd_kafka_consume_start_queue() function occurrence");
//        return 0;
//    }
//
//    printf("rd_kafka_consume_start_queue() call intercepted\n");
//
//    return o_rd_kafka_consume_start_queue(rkt, partition, offset, rkqu);
//}
//
//rd_kafka_queue_t *rd_kafka_queue_new(rd_kafka_t *rk) {
//    o_rd_kafka_queue_new = dlsym(RTLD_NEXT, "rd_kafka_queue_new");
//    if (o_rd_kafka_queue_new == NULL) {
//        printf("Could not find next rd_kafka_queue_new() function occurrence");
//        return NULL;
//    }
//
//    printf("rd_kafka_queue_new() call intercepted\n");
//
//    return o_rd_kafka_queue_new(rk);
//}
//
//ssize_t rd_kafka_consume_batch(rd_kafka_topic_t *rkt, int32_t partition,
//				int timeout_ms,
//				rd_kafka_message_t **rkmessages,
//				size_t rkmessages_size) {
//    o_rd_kafka_consume_batch = dlsym(RTLD_NEXT, "rd_kafka_consume_batch");
//    if (o_rd_kafka_consume_batch == NULL) {
//        printf("Could not find next rd_kafka_consume_batch() function occurrence");
//        return 0;
//    }
//    printf("rd_kafka_consume_batch() call intercepted\n");
//
//    return o_rd_kafka_consume_batch(rkt, partition, timeout_ms, rkmessages, rkmessages_size);
//}
//
//int rd_kafka_poll(rd_kafka_t *rk, int timeout_ms) {
//    o_rd_kafka_poll = dlsym(RTLD_NEXT, "rd_kafka_poll");
//    if (o_rd_kafka_poll == NULL) {
//        printf("Could not find next rd_kafka_poll() function occurrence");
//        return 0;
//    }
//    printf("rd_kafka_poll() call intercepted\n");
//
//    return o_rd_kafka_poll(rk, timeout_ms);
//}

int rd_kafka_brokers_add(rd_kafka_t *rk, const char *brokerlist) {
    o_rd_kafka_brokers_add = dlsym(RTLD_NEXT, "rd_kafka_brokers_add");
    if (o_rd_kafka_new == NULL) {
        printf("Could not find next rd_kafka_brokers_add() function occurrence");
        return 0;
    }
    printf("rd_kafka_brokers_add() call intercepted\n");

    char hostname[32];
    int port;
    sscanf(brokerlist, "%[^:]:%d", hostname, &port);

    return 1;

    return o_rd_kafka_brokers_add(rk, brokerlist);
}

rd_kafka_topic_t *rd_kafka_topic_new(rd_kafka_t *rk, const char *topic,
				      rd_kafka_topic_conf_t *conf) {
    o_rd_kafka_topic_new = dlsym(RTLD_NEXT, "rd_kafka_topic_new");
    if (o_rd_kafka_topic_new == NULL) {
        printf("Could not find next rd_kafka_topic_new() function occurrence");
        return NULL;
    }
    //printf("rd_kafka_topic_new() call intercepted\n");

    sscanf(topic, "%x", &nk_topic_tag);

    return o_rd_kafka_topic_new(rk, topic, conf);
}


rd_kafka_t *rd_kafka_new(rd_kafka_type_t type, rd_kafka_conf_t *conf,
			  char *errstr, size_t errstr_size) {

    o_rd_kafka_new = dlsym(RTLD_NEXT, "rd_kafka_new");
    if (o_rd_kafka_new == NULL) {
        printf("Could not find next rd_kafka_new() function occurrence");
        return NULL;
    }
    printf("rd_kafka_new() call intercepted\n");

    hook_mode = type;
    bzero((char *)&tmp_msg, sizeof(tmp_msg));
    bzero((char *)&tmp_payload, sizeof(tmp_payload));
    tmp_msg.payload = tmp_payload;
    tmp_msg.len = 32;

    assert(nk_cl == NULL);
    //if (type == RD_KAFKA_PRODUCER)
    //    nk_cl = netkafka_producer_new("127.0.0.1", 40001);
    //else
    //    nk_cl = netkafka_consumer_new(30002);
    if (type == RD_KAFKA_PRODUCER)
        nk_cl = netkafka_producer_new("255.255.255.255", 1234);
    else
        nk_cl = netkafka_consumer_new(1234);

    nk_rk = o_rd_kafka_new(type, conf, errstr, errstr_size);
    return nk_rk;
}

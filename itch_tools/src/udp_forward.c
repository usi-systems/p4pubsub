#include "common.c"

#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <libgen.h>
#include <pthread.h>
#include "liblfds710.h"

#define BUFSIZE 2048

struct sockaddr_in sock_addr;
int sock_fd;
struct lfds710_queue_bmm_state qbmms;

struct queue_pkt {
    size_t size;
    char buf[BUFSIZE];
};

void *sender(void *ignored) {
    struct queue_pkt *pkt;

    LFDS710_MISC_MAKE_VALID_ON_CURRENT_LOGICAL_CORE_INITS_COMPLETED_BEFORE_NOW_ON_ANY_OTHER_LOGICAL_CORE;

    while (1) {
        while (!lfds710_queue_bmm_dequeue(&qbmms, NULL, (void **)&pkt)) {
            // Spin until pkt is dequeued
        }

        if (pkt == NULL)
            break;

        //usleep(1000000);
        sendto(sock_fd, pkt->buf, pkt->size, 0, (struct sockaddr *)&sock_addr, sizeof(sock_addr));
    }
}

char *progname;
void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-b SO_RCVBUF] [-q Q_SIZE] LISTEN_HOST LISTEN_PORT DST_HOST DST_PORT\n\
\n\
\n\
", progname);
    exit(rc);
}

int main(int argc, char *argv[]) {
    int opt;
    int queue_size = 64;
    int rcvbuf = 0;
    progname = basename(argv[0]);
    while ((opt = getopt(argc, argv, "hb:q:")) != -1) {
        switch (opt) {
            case 'b':
                rcvbuf = atoi(optarg);
                break;
            case 'q':
                queue_size = atoi(optarg);
                break;
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

    if (argc - optind != 4) {
        usage(-1);
    }

    if (!is_pow2(queue_size)) {
        fprintf(stderr, "Queue size must be a power of 2 (e.g. 2, 4, 8, 16, etc.)\n");
        usage(-1);
    }

    char *listen_host = argv[optind];
    char *listen_port = argv[optind+1];
    char *dst_host = argv[optind+2];
    char *dst_port = argv[optind+3];

    sock_fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);

    sock_addr.sin_family = AF_INET;
    sock_addr.sin_addr.s_addr = inet_addr(listen_host);
    sock_addr.sin_port = htons(atoi(listen_port));
    if (bind(sock_fd, (struct sockaddr *)&sock_addr, sizeof(sock_addr)) == -1)
        error("bind()");

    if (rcvbuf > 0) {
        if (setsockopt(sock_fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf)) < 0)
            error("setsockopt()");
    }

    sock_addr.sin_addr.s_addr = inet_addr(dst_host);
    sock_addr.sin_port = htons(atoi(dst_port));

    struct sockaddr_in sa;
    int sa_size = sizeof(sa);

    struct lfds710_queue_bmm_element qbmme[queue_size];
    lfds710_queue_bmm_init_valid_on_current_logical_core(&qbmms, qbmme, queue_size, NULL);

    pthread_t sender_thread;
    if (pthread_create(&sender_thread, NULL, sender, NULL))
        error("pthread_create()");

    int num_pkt_bufs = queue_size + 2;
    int pkt_buf_idx = -1;
    struct queue_pkt *pkt;
    struct queue_pkt *pkt_buf = (struct queue_pkt *)malloc(sizeof(struct queue_pkt) * num_pkt_bufs);

	while (1) {
        pkt_buf_idx = (pkt_buf_idx + 1) % num_pkt_bufs;
        pkt = pkt_buf + pkt_buf_idx;

        pkt->size = recvfrom(sock_fd, pkt->buf, BUFSIZE, 0, (struct sockaddr *)&sa, &sa_size);
        if (pkt->size <= 0)
            continue;

        while (!lfds710_queue_bmm_enqueue(&qbmms, NULL, pkt)) {
            // Spin until pkt is enqueued
        }
    }

    lfds710_queue_bmm_cleanup(&qbmms, NULL);

}

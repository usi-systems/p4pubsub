#include "common.c"
#include "int_udp.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <string.h>
#include <libgen.h>
#include <signal.h>
#include <fcntl.h>
#include <assert.h>


#define BUFSIZE 2048

char *progname;

int verbosity = 0;

int sockfd = 0;
int pkt_cnt = 0;

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-v VERBOSITY] [-p CPU] [-o OPTIONS] [-B COUNT] [-b SO_RCVBUF] [-m MAX_PKTS] LISTEN_PORT\n\
\n\
    -p CPU     Pin process to CPU.\n\
\n\
OPTIONS is a string of chars, which can include:\n\
    p - pretty print INT packets\n\
\n\
\n\
", progname);
    exit(rc);
}

void cleanup_and_exit() {
    if (sockfd)
        close(sockfd);

    fprintf(stderr, "\nReceived %d packets\n", pkt_cnt);
    exit(0);
}

void catch_int(int signo) {
    cleanup_and_exit();
}

void pp_int(char *buf, size_t size) {
    size_t ofst = 0;

    struct int_probe_marker *probe = (struct int_probe_marker *)buf;
    if (probe->marker1 != int_probe_marker1 || probe->marker2 != int_probe_marker2) {
        printf("< Not an INT packet >\n");
        return;
    }
    ofst += sizeof(struct int_probe_marker);
    assert(ofst < size);

    struct intl4_shim *shim = (struct intl4_shim *) (buf + ofst);
    printf("intl4_shim\n\ttype: %u\n\tlen: %u\n\n", shim->int_type, shim->len);
    ofst += sizeof(struct intl4_shim);
    assert(ofst < size);

    struct int_header *hdr = (struct int_header *) (buf + ofst);
    printf("int_header\n\tremaining_hop_cnt: %u\n\tins_mask1: %u\n\n", hdr->remaining_hop_cnt, hdr->instruction_mask_0007);
    ofst += sizeof(struct int_header);
    assert(ofst < size);

    struct int_switch_id *swid = (struct int_switch_id *) (buf + ofst);
    printf("switch_id: %X\n", ntohl(swid->switch_id));
    ofst += sizeof(struct int_switch_id);
    assert(ofst < size);

    struct int_hop_latency *hl = (struct int_hop_latency *) (buf + ofst);
    printf("hop_latency: %X\n", ntohl(hl->hop_latency));
    ofst += sizeof(struct int_hop_latency);
    assert(ofst < size);

    struct int_q_occupancy *qo = (struct int_q_occupancy *) (buf + ofst);
    unsigned occ = (qo->q_occupancy1 << 16) | (qo->q_occupancy2 << 8) | qo->q_occupancy3;
    printf("q_id %d occ: %X\n", qo->q_id, occ);
    ofst += sizeof(struct int_q_occupancy);

}

int main(int argc, char *argv[]) {
    int opt;
    int port;
    char *extra_options = 0;
    int do_pretty_print = 0;
    int rcvbuf = 0;
    int max_packets = 0;
    int pin_cpu = -1;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "hb:m:o:p:v:")) != -1) {
        switch (opt) {
            case 'b':
                rcvbuf = atoi(optarg);
                break;
            case 'm':
                max_packets = atoi(optarg);
                break;
            case 'o':
                extra_options = optarg;
                break;
            case 'p':
                pin_cpu = atoi(optarg);
                break;
            case 'v':
                verbosity = atoi(optarg);
                break;
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

	if (argc - optind != 1) {
		usage(-1);
	}

    port = atoi(argv[optind+0]);

    if (extra_options) {
        if (strchr(extra_options, 'p'))
            do_pretty_print = 1;
    }

    if (pin_cpu > -1) {
        pin_thread(pin_cpu);
        if (verbosity > 0)
            fprintf(stderr, "Pinned process to CPU %d\n", pin_cpu);
    }

    signal(SIGINT, catch_int);


    int i, size;
    struct sockaddr_in localaddr;
    struct sockaddr_in remoteaddr;
    char buf[BUFSIZE];

    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0)
        error("socket()");

    int optval = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR,
            (const void *)&optval , sizeof(int));

    bzero((char *)&localaddr, sizeof(localaddr));
    localaddr.sin_family = AF_INET;
    localaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    localaddr.sin_port = htons(port);

    if (bind(sockfd, (struct sockaddr *)&localaddr, sizeof(localaddr)) < 0)
        error("bind()");

    if (verbosity > 0)
        fprintf(stderr, "Listenning on port %d\n", port);

    if (rcvbuf > 0) {
        if (setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf)) < 0)
            error("setsockopt()");
        if (verbosity > 0)
            printf("Socket kernel receive buffer set to %d bytes\n", rcvbuf);
    }

    int remoteaddr_len = sizeof(remoteaddr);

    while (1) {

        size = recvfrom(sockfd, buf, BUFSIZE, 0,
                (struct sockaddr *)&remoteaddr, &remoteaddr_len);
        if (size < 0)
            error("recvfrom()");

        pkt_cnt++;

        if (do_pretty_print)
            pp_int(buf, size);

        if (max_packets && pkt_cnt == max_packets)
            break;
    }

    cleanup_and_exit();

    return 0;
}

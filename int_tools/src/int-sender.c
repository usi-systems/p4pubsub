#include "common.c"
#include "int_udp.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <libgen.h>

#define BUFSIZE 2048

char *progname;
void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-c COUNT] [-r REMAINING_HOP_CNT] DST_HOST DST_PORT\n\
\n\
", progname);
    exit(rc);
}

size_t make_int_payload(char *buf, uint8_t remaining_hop_cnt) { // returns size of payload
    size_t ofst = 0;

    struct int_probe_marker *probe = (struct int_probe_marker *)buf;
    probe->marker1 = int_probe_marker1;
    probe->marker2 = int_probe_marker2;
    ofst += sizeof(struct int_probe_marker);

    struct intl4_shim *shim = (struct intl4_shim *) (buf + ofst);
    bzero(shim, sizeof(struct intl4_shim));
    shim->int_type = 1;
    size_t len_bytes = sizeof(struct intl4_shim) + sizeof(struct int_header) + sizeof(struct int_switch_id) + sizeof(struct int_hop_latency);
    shim->len = len_bytes / 4; // length in 4-byte words
    ofst += sizeof(struct intl4_shim);

    struct int_header *hdr = (struct int_header *) (buf + ofst);
    bzero(hdr, sizeof(struct int_header));
    hdr->ver_rep_c_e = 1 << 4;
    hdr->remaining_hop_cnt = remaining_hop_cnt;
    hdr->instruction_mask_0007 = 11 << 4; // bits: 1011
    ofst += sizeof(struct int_header);

    struct int_switch_id *swid = (struct int_switch_id *) (buf + ofst);
    swid->switch_id = htonl(0xAAAAAAAA);
    ofst += sizeof(struct int_switch_id);

    struct int_hop_latency *hl = (struct int_hop_latency *) (buf + ofst);
    hl->hop_latency = htonl(0xBBBBBBBB);
    ofst += sizeof(struct int_hop_latency);

    struct int_q_occupancy *qo = (struct int_q_occupancy *) (buf + ofst);
    qo->q_id = 1;
    qo->q_occupancy1 = 0xCC;
    qo->q_occupancy2 = 0xCC;
    qo->q_occupancy3 = 0xCC;
    ofst += sizeof(struct int_q_occupancy);

    return ofst;
}

int main(int argc, char *argv[]) {
    int opt, i, sock_fd;
    struct sockaddr_in sock_addr;
    int count = 8;
    int remaining_hop_cnt = 2;

    progname = basename(argv[0]);
    while ((opt = getopt(argc, argv, "hc:r:")) != -1) {
        switch (opt) {
            case 'c':
                count = atoi(optarg);
                break;
            case 'r':
                remaining_hop_cnt = atoi(optarg);
                break;
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

    char buf[BUFSIZE];
    bzero(buf, BUFSIZE);

	if (argc - optind != 2) {
		usage(-1);
	}

    char *dst_host = argv[optind+0];
    char *dst_port = argv[optind+1];

	sock_fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);

	sock_addr.sin_family = AF_INET;
	sock_addr.sin_addr.s_addr = 0;
    sock_addr.sin_port = 0;
	if (bind(sock_fd, (struct sockaddr *)&sock_addr, sizeof(sock_addr)) == -1)
        error("bind()");

	sock_addr.sin_addr.s_addr = inet_addr(dst_host);
    sock_addr.sin_port = htons(atoi(dst_port));

    size_t payload_size;

    for (i = 0; i < count; i++) {
        payload_size = make_int_payload(buf, remaining_hop_cnt);
        sendto(sock_fd, buf, payload_size, 0, (struct sockaddr *)&sock_addr, sizeof(sock_addr));
	}

    close(sock_fd);

    return 0;
}

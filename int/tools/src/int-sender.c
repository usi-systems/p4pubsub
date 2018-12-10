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

//#define SEND_WAIT_US 1

char *progname;
void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-c COUNT] [-m MATCH_RATIO] [-n REMAINING_HOP_CNT] DST_HOST DST_PORT\n\
\n\
", progname);
    exit(rc);
}

size_t make_int_payload(char *buf, uint8_t remaining_hop_cnt, uint32_t switch_id) { // returns size of payload
    size_t ofst = 0;

    struct int_probe_marker *probe = (struct int_probe_marker *)buf;
    probe->marker1 = int_probe_marker1;
    probe->marker2 = int_probe_marker2;
    ofst += sizeof(struct int_probe_marker);

    struct intl4_shim *shim = (struct intl4_shim *) (buf + ofst);
    bzero(shim, sizeof(struct intl4_shim));
    shim->int_type = 1;
    size_t len_bytes = sizeof(struct intl4_shim) + sizeof(struct int_header) + sizeof(struct int_switch_id) + sizeof(struct int_hop_latency) + sizeof(struct int_q_occupancy);
    shim->len = len_bytes / 4; // length in 4-byte words
    ofst += sizeof(struct intl4_shim);

    struct int_header *hdr = (struct int_header *) (buf + ofst);
    bzero(hdr, sizeof(struct int_header));
    hdr->ver_rep_c_e = 1 << 4;
    hdr->remaining_hop_cnt = remaining_hop_cnt;
    hdr->instruction_mask_0007 = 11 << 4; // bits: 1011
    ofst += sizeof(struct int_header);

    struct int_switch_id *swid = (struct int_switch_id *) (buf + ofst);
    swid->switch_id = htonl(switch_id);
    ofst += sizeof(struct int_switch_id);

    struct int_hop_latency *hl = (struct int_hop_latency *) (buf + ofst);
    hl->hop_latency = htonl(8000);
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
    unsigned count = 8;
    int remaining_hop_cnt = 2;
    float match_ratio = 0.01;

    progname = basename(argv[0]);
    while ((opt = getopt(argc, argv, "hc:m:n:")) != -1) {
        switch (opt) {
            case 'c':
                count = atoi(optarg);
                break;
            case 'm':
                match_ratio = atof(optarg);
                break;
            case 'n':
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
    uint32_t matching_switch_id = 22;
    uint32_t switch_id;
    int match_nth = 1/match_ratio;

    fprintf(stderr, "Matching on every %d\n", match_nth);

    for (i = 0; i < count; i++) {

        if (i % match_nth == 0)
            switch_id = matching_switch_id;
        else
            switch_id = 1; // receiver should not match on this

        payload_size = make_int_payload(buf, remaining_hop_cnt, switch_id);
        sendto(sock_fd, buf, payload_size, 0, (struct sockaddr *)&sock_addr, sizeof(sock_addr));

#if SEND_WAIT_US > 0
        usleep(SEND_WAIT_US);
#endif
	}

    close(sock_fd);

    return 0;
}

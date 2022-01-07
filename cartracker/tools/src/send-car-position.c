#include "car_tracker.h"

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

#define SEND_WAIT_US 0

void error(const char *msg);

void error(const char *msg) {
    perror(msg);
    exit(0);
}

char *progname;
void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-c COUNT] [-s SPEED] [-l LAT] [-L LON] DST_HOST DST_PORT\n\
\n\
", progname);
    exit(rc);
}

size_t make_car_payload(char *buf, uint16_t lat, uint16_t lon, uint16_t speed) { // returns size of payload

    struct car_tracker_hdr *h = (struct car_tracker_hdr *)buf;
    h->lat = htons(lat);
    h->lon = htons(lon);
    h->speed = htons(speed);

    return sizeof(struct car_tracker_hdr);
}

int main(int argc, char *argv[]) {
    int opt, i, sock_fd;
    struct sockaddr_in sock_addr;
    unsigned count = 8;
    int remaining_hop_cnt = 2;
    int speed = 10;
    int lat = 12, lon = 12;
    float match_ratio = 0.01;

    progname = basename(argv[0]);
    while ((opt = getopt(argc, argv, "hc:l:L:s:")) != -1) {
        switch (opt) {
            case 'c':
                count = atoi(optarg);
                break;
            case 'l':
                lat = atoi(optarg);
                break;
            case 'L':
                lon = atoi(optarg);
                break;
            case 's':
                speed = atoi(optarg);
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

        payload_size = make_car_payload(buf, lat, lon, speed);
        sendto(sock_fd, buf, payload_size, 0, (struct sockaddr *)&sock_addr, sizeof(sock_addr));

#if SEND_WAIT_US > 0
        usleep(SEND_WAIT_US);
#endif
	}

    close(sock_fd);

    return 0;
}

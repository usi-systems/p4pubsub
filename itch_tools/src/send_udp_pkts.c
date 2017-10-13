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

#include "common.c"

#define BUFSIZE 2048

char *progname;
void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-c COUNT] DST_HOST DST_PORT\n\
\n\
", progname);
    exit(rc);
}

int main(int argc, char *argv[]) {
    int opt, i, sock_fd;
    struct sockaddr_in sock_addr;
    char buf[1024];
    int count = 8;

    progname = basename(argv[0]);
    while ((opt = getopt(argc, argv, "hc:")) != -1) {
        switch (opt) {
            case 'c':
                count = atoi(optarg);
                break;
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

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

    for (i = 0; i < count; i++) {
        sprintf(buf, "%d\n", i);
        sendto(sock_fd, buf, strlen(buf)+1, 0, (struct sockaddr *)&sock_addr, sizeof(sock_addr));
	}

    close(sock_fd);
}


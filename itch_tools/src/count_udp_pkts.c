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
#include <signal.h>

#define BUFSIZE 2048

void error(const char *msg) {
    perror(msg);
    exit(0);
}


char *progname;
void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-c MAX_CNT] LISTEN_PORT\n\
\n\
", progname);
    exit(rc);
}


int sock_fd;
volatile int finished = 0;
volatile int sock_closed = 0;

void catch_int(int signo) {
    printf("\n");
    finished = 1;
    sock_closed = 1;
    close(sock_fd);
}

int main(int argc, char *argv[]) {
    int opt;
    struct sockaddr_in sock_addr;
    char buf[BUFSIZE];
    uint64_t cnt = 0;
    int max_count = 0;

    progname = basename(argv[0]);
    while ((opt = getopt(argc, argv, "hc:")) != -1) {
        switch (opt) {
            case 'c':
                max_count = atoi(optarg);
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

    int port = atoi(argv[optind]);

	sock_fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);

    int optval = 1;
    setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR,
            (const void *)&optval , sizeof(int));

	sock_addr.sin_family = AF_INET;
	sock_addr.sin_addr.s_addr = 0;
    sock_addr.sin_port = htons(port);

	if (bind(sock_fd, (struct sockaddr *)&sock_addr, sizeof(sock_addr)) == -1)
        error("bind()");

    int rcvbuf = 16 * 1024 * 1024;
    if (setsockopt(sock_fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf)) < 0)
        error("setsockopt()");

    int disable = 1;
    if (setsockopt(sock_fd, SOL_SOCKET, SO_NO_CHECK, &disable, sizeof(disable)) < 0)
        error("setsockopt()");

    signal(SIGINT, catch_int);

    while (!finished && (max_count == 0 || cnt < max_count)) {
        size_t size = recvfrom(sock_fd, buf, BUFSIZE, 0, NULL, NULL);
        if (size < 0)
            error("recvfrom()");
        if (size == 0) break;
        cnt++;
    }

    printf("%lu\n", cnt);

    if (!sock_closed)
    close(sock_fd);
}


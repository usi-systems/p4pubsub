#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <libgen.h>

#define BUFSIZE 2048

void error(const char *msg) {
    perror(msg);
    exit(0);
}

char *progname;
void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-b SO_RCVBUF] LISTEN_HOST LISTEN_PORT\n\
\n\
\n\
", progname);
    exit(rc);
}

int main(int argc, char *argv[]) {
    int opt;
    int rcvbuf = 0;
    struct sockaddr_in sock_addr;
    int sock_fd;

    progname = basename(argv[0]);
    while ((opt = getopt(argc, argv, "hb:q:")) != -1) {
        switch (opt) {
            case 'b':
                rcvbuf = atoi(optarg);
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

    char *listen_host = argv[optind];
    char *listen_port = argv[optind+1];

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

    struct sockaddr_in sa;
    int sa_size = sizeof(sa);

    char buf[BUFSIZE];
    size_t payload_bytes;

	while (1) {
        payload_bytes = recvfrom(sock_fd, buf, BUFSIZE, 0, (struct sockaddr *)&sa, &sa_size);
        if (payload_bytes == 0)
            continue;
        if (payload_bytes < 0)
            break;

        printf("Received %ld bytes\n", payload_bytes);
    }

}

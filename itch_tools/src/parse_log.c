#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <libgen.h>
#include <assert.h>

#include "common.c"

char *my_hostname;

char *progname;

void error(char *msg) {
    perror(msg);
    exit(0);
}

void usage(int rc) {
    printf("Usage: %s LOG_FILENAME\n", progname);
    exit(rc);
}

int main(int argc, char *argv[]) {
    int opt;
    char *log_filename = 0;
    int n;
    int fd_log = -1;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "h")) != -1) {
        switch (opt) {
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

    if (argc - optind != 1)
        usage(-1);

    log_filename = argv[optind];

    fd_log = open(log_filename, O_RDONLY);
    if (fd_log < 0)
        error("open() log_filename");

    unsigned long long sent = 0;
    unsigned long long received = 0;

    unsigned long long delta;

    struct log_record rec;

    while (1) {
        n = read(fd_log, &rec, sizeof(rec));
        if (n == 0) break;
        sent = ntoh48(*rec.sent_ns_since_midnight);
        memcpy(&received, rec.received_ns_since_midnight, 6);

        delta = received - sent;
        printf("%lld\t%lld\t%s\n", sent, delta, rec.stock);
    }

    close(fd_log);

    return 0;
}

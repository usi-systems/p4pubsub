#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <libgen.h>
#include <assert.h>


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

    unsigned long long sent;
    unsigned long long received;
    char stock[9];
    stock[8] = '\0';

    unsigned long long delta;

    while (1) {
        n = read(fd_log, &sent, 6);
        if (n == 0) break;
        n = read(fd_log, &received, 6);
        assert(n > 0);
        n = read(fd_log, stock, 8);
        assert(n > 0);

        delta = received - sent;
        printf("%lld\t%lld\t%s\n", sent, delta, stock);
    }

    close(fd_log);

    return 0;
}

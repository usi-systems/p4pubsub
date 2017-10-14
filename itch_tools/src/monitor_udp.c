#include "common.c"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <libgen.h>

char *progname;

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s  [-t SLEEP_SECS] PORT\n\
\n\
", progname);
    exit(rc);
}

int main(int argc, char *argv[]) {
    int opt;
    int sleep_us = 1000000;
    int port;
    FILE *fh;
    char line_filter[64];
    char line[256];
    char *field, *unused;
    short found;
    short i;
    unsigned rx_q, tx_q;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "ht:")) != -1) {
        switch (opt) {
            case 't':
                sleep_us = atoi(optarg);
                break;
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

    if (argc - optind != 1)
        usage(-1);

    port = atoi(argv[optind]);

    sprintf(line_filter, ":%02X ", port);

    while (1) {
        fh = fopen("/proc/net/udp", "r");

        unused = fgets(line, sizeof(line), fh); // Skip header line

        found = 0;
        while (fgets(line, sizeof(line), fh)) {
            if (!strstr(line, line_filter)) continue;

            // Split the line on " " and get the 4th field:
            field = strtok(line, " ");
            for (i = 0; i < 4; i++) field = strtok(NULL, " ");

            sscanf(field, "%d:%d", &tx_q, &rx_q);

            printf("%lld\t%u\t%u\n", ns_since_midnight(), rx_q, tx_q);

            found = 1;
            break;
        }

        fclose(fh);

        if (!found) {
            fprintf(stderr, "Could not find socket for port %d. Exiting.\n", port);
            break;
        }

        usleep(sleep_us);
    }

    return 0;
}

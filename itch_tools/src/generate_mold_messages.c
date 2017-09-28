#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <netdb.h>
#include <libgen.h>

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

#include "common.c"

char *progname;

void error(char *msg) {
    perror(msg);
    exit(-1);
}


#define BUFSIZE 2048
char buf[BUFSIZE];

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
    "Usage: %s [-m MIN_MSG_CNT] [-M MAX_MSG_CNT] [-p PKT_COUNT] [-r ITCH_FILE] [-o OUT_FILENAME]\n\
\n\
", progname);
    exit(rc);
}

int random_int(int min, int max) {
    if (min == max) return min;
    return min + rand() % (max+1 - min);
}

char *stocks[] = {"ABC     ", "XYZ     ", "1234    "};

int make_ao_msg(void *out_buf, int shares, int price) {
    struct omx_moldudp64_message *mm;
    struct itch50_msg_add_order *ao;
    uint16_t msg_len = sizeof(struct itch50_msg_add_order);

    mm = (struct omx_moldudp64_message *) out_buf;
    mm->MessageLength = htons(msg_len);

    ao = (struct itch50_msg_add_order *) ((void *)mm + 2);
    bzero(ao, msg_len);
    ao->MessageType = ITCH50_MSG_ADD_ORDER;
    ao->BuySellIndicator = 'S';
    ao->Price = htonl(price);
    ao->Shares = htonl(shares);
    memcpy(ao->Stock, stocks[0], 8);
    return msg_len;
}

int read_next_msg(FILE *fh, void *out_buf) {

    if (!fread(out_buf, sizeof(uint16_t), 1, fh)) {
        if (feof(fh))
            return 0;
        else
            error("fread()");
    }

    const uint16_t msg_len = ntohs(*(uint16_t *)(out_buf));
    if (!fread(out_buf + sizeof(uint16_t), msg_len, 1, fh))
        error("fread()");

    return msg_len;
}


int main(int argc, char *argv[]) {
    int opt, n;
    int fd_out = 0;
    FILE *fh_in = 0;
    unsigned min_msgs = 0;
    unsigned max_msgs = 0;
    char *out_filename = 0;
    char *in_filename = 0;
    int pkt_count = 10;
    char *extra_options = 0;
    uint64_t tmp_seq_num;
    struct omx_moldudp64_header *h;
    struct itch50_message *m;
    int pkt_offset;
    int msg_count;
    int msg_num;
    int msg_len;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "ha:r:o:p:m:M:")) != -1) {
        switch (opt) {
            case 'a':
                extra_options = optarg;
                break;
            case 'o':
                out_filename = optarg;
                break;
            case 'r':
                in_filename = optarg;
                break;
            case 'm':
                min_msgs = atoi(optarg);
                break;
            case 'M':
                max_msgs = atoi(optarg);
                break;
            case 'p':
                pkt_count = atoi(optarg);
                break;
            case 'h':
                usage(0);
                break;
            default: /* '?' */
                usage(-1);
        }
    }


    if (argc - optind != 0)
        usage(-1);

    if (max_msgs == 0)
        max_msgs = min_msgs;

    if (min_msgs == 0)
        min_msgs = max_msgs;


    if (extra_options) {
    }

    fd_out = 1;
    if (out_filename) {
        if (strcmp(out_filename, "-") != 0) {
            fd_out = open(out_filename, O_WRONLY | O_CREAT | O_TRUNC, 0664);
            if (fd_out < 0)
                error("open() out_filename");
        }
    }

    if (in_filename) {
        if (strcmp(in_filename, "-") == 0)
            fh_in = stdin;
        else {
            fh_in = fopen(in_filename, "rb");
            if (!fh_in)
                error("fopen()");
        }
    }


    uint64_t seq_num = 1;

    short stop = 0;

    while (!stop) {
        msg_count = random_int(min_msgs, max_msgs);
        h = (struct omx_moldudp64_header *)buf;
        bzero(h->Session, 8);
        h->SequenceNumber = htonll(seq_num);

        pkt_offset = sizeof(struct omx_moldudp64_header);


        for (msg_num = 0; msg_num < msg_count; msg_num++) {
            if (fh_in) {
                msg_len = read_next_msg(fh_in, buf + pkt_offset);
                if (msg_len == 0) {
                    stop = 1;
                    break;
                }
            }
            else {
                msg_len = make_ao_msg(buf + pkt_offset, seq_num, msg_num);
            }

            pkt_offset += msg_len + 2;
        }

        h->MessageCount = htons(msg_num);

        n = write(fd_out, buf, pkt_offset);
        if (n < 0)
            error("write()");

        seq_num++;
        if (seq_num > pkt_count && pkt_count != 0)
            stop = 1;
    }

    if (fd_out > -1)
        close(fd_out);

    if (fh_in)
        fclose(fh_in);

    return 0;
}

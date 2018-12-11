/*-
 *   BSD LICENSE
 *
 *   Copyright(c) 2010-2015 Intel Corporation. All rights reserved.
 *   All rights reserved.
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in
 *       the documentation and/or other materials provided with the
 *       distribution.
 *     * Neither the name of Intel Corporation nor the names of its
 *       contributors may be used to endorse or promote products derived
 *       from this software without specific prior written permission.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 *   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 *   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 *   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
// This must be included first
#include "../src/common.c"

#include <stdint.h>
#include <inttypes.h>
#include <unistd.h>
#include <signal.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_ip.h>
#include <rte_udp.h>

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

#define RX_RING_SIZE 4096
#define TX_RING_SIZE 64

#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 32
// Smallest burst size supported by this NIC:
#define MIN_BURST_SIZE 4

#define WRAP_LOG

static const struct rte_eth_conf port_conf_default = {
    .link_speeds = ETH_LINK_SPEED_25G,
    .rxmode = {
        .mq_mode        = ETH_MQ_RX_RSS,
        .max_rx_pkt_len = ETHER_MAX_LEN,
        .split_hdr_size = 0,
        .header_split   = 0,
        .hw_ip_checksum = 0,
        .hw_vlan_filter = 0,
        .jumbo_frame    = 0,
        .hw_strip_crc   = 0,
    },
    .rx_adv_conf = {
        .rss_conf = {
            .rss_key = NULL,
            .rss_hf  = ETH_RSS_IP,
        }
    },
    .txmode = {
    },
};

struct rte_mempool *mbuf_pool;

/* basicfwd.c: Basic DPDK skeleton forwarding example. */

/*
 * Initializes a given port using global settings and with the RX buffers
 * coming from the mbuf_pool passed as a parameter.
 */
static inline int
port_init(uint16_t port)
{
	struct rte_eth_conf port_conf = port_conf_default;
	const uint16_t rx_rings = 1, tx_rings = 1;
	uint16_t nb_rxd = RX_RING_SIZE;
	uint16_t nb_txd = TX_RING_SIZE;
	int retval;
	uint16_t q;

	if (port >= rte_eth_dev_count())
		return -1;

	/* Configure the Ethernet device. */
	retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
	if (retval != 0)
		return retval;

	retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
	if (retval != 0)
		return retval;

	/* Allocate and set up 1 RX queue per Ethernet port. */
	for (q = 0; q < rx_rings; q++) {
		retval = rte_eth_rx_queue_setup(port, q, nb_rxd,
				rte_eth_dev_socket_id(port), NULL, mbuf_pool);
		if (retval < 0)
			return retval;
	}

	/* Allocate and set up 1 TX queue per Ethernet port. */
	for (q = 0; q < tx_rings; q++) {
		retval = rte_eth_tx_queue_setup(port, q, nb_txd,
				rte_eth_dev_socket_id(port), NULL);
		if (retval < 0)
			return retval;
	}

	/* Start the Ethernet port. */
	retval = rte_eth_dev_start(port);
	if (retval < 0)
		return retval;

	/* Display the port MAC address. */
	struct ether_addr addr;
	rte_eth_macaddr_get(port, &addr);
	printf("Port %u MAC: %02" PRIx8 " %02" PRIx8 " %02" PRIx8
			   " %02" PRIx8 " %02" PRIx8 " %02" PRIx8 "\n",
			port,
			addr.addr_bytes[0], addr.addr_bytes[1],
			addr.addr_bytes[2], addr.addr_bytes[3],
			addr.addr_bytes[4], addr.addr_bytes[5]);

	/* Enable RX in promiscuous mode for the Ethernet device. */
	rte_eth_promiscuous_enable(port);

	return 0;
}

uint16_t receiver_port;
uint16_t sender_port;

int only_receiver = 0;
int only_sender = 0;

uint64_t expected_matches = 0;

int itch_port = 1234;

unsigned send_rate_pps = 0;
int send_cnt = 0;
int print_interval_pkts = 1 * 1000 * 1000;

uint64_t send_start_ns = 0;
uint64_t send_end_ns = 0;
uint64_t send_start_opackets;
uint64_t send_start_obytes;


const char dst_mac[] = {0x3c, 0xfd, 0xfe, 0xa6, 0x7e, 0x5d};
unsigned dst_addr = 0x0a000002;
uint64_t send_timestamp;
uint64_t recv_timestamp;

unsigned total_tx = 0;
unsigned total_rx = 0;
unsigned total_resent = 0;
unsigned total_matches = 0;

char *log_filename = 0;
FILE *fh_log = 0;
int log_buffer_max_entries = 100 * 1000 * 1000;
int log_entries_count = 0;
int log_flushed_count = 0;
struct log_record *log_buffer;

char *in_filename = NULL;
size_t in_file_size;
char *in_buf = NULL;
char *in_buf_cur = NULL;

void load_send_file() {
    FILE *fh = fopen(in_filename, "rb");
    if (!fh)
        error("fopen()");
    fseek(fh, 0, SEEK_END);
    in_file_size = ftell(fh);
    fseek(fh, 0, SEEK_SET);

    printf("Loading %s into memory... ", in_filename);
    fflush(stdout);
    in_buf =  (char *)malloc(in_file_size);
    if (!fread(in_buf, in_file_size, 1, fh))
        error("fread()");
    fclose(fh);
    printf("done.\n");

    in_buf_cur = in_buf;
}


char filter_stock[9];
char *default_stock = "ABC123  ";

int matches_filter(struct itch50_msg_add_order *ao) {
#if 0
    return 1;
#else
    if (memcmp(filter_stock, ao->Stock, STOCK_SIZE) == 0)
        return 1;
    return 0;
#endif
}


void flush_log() {
    size_t outstanding = log_entries_count - log_flushed_count;
    if (outstanding > log_buffer_max_entries) // this can happen with WRAP_LOG
        outstanding = log_buffer_max_entries;
    fwrite(log_buffer, outstanding*sizeof(struct log_record), 1, fh_log);
    log_flushed_count += outstanding;
}

void log_add_order(struct itch50_msg_add_order *ao) {
    double time_scale_ns = 1e9 / rte_get_tsc_hz();
    recv_timestamp = rte_rdtsc() * time_scale_ns;
    struct log_record *rec = log_buffer + (log_entries_count % log_buffer_max_entries);
    memcpy(rec->sent_ns_since_midnight, ao->Timestamp, 6);
    memcpy(rec->received_ns_since_midnight, &recv_timestamp, 6);
    memcpy(rec->stock, ao->Stock, 8);
    log_entries_count++;

#ifndef WRAP_LOG
    if (unlikely(log_entries_count % log_buffer_max_entries == 0))
        flush_log();
#endif // ifdef WRAP_LOG
}

void cleanup_and_exit() {
    struct rte_eth_stats stats;

    rte_eth_stats_get(receiver_port, &stats);
    printf("\ntotal_rx: %u, ipackets: %lu, imissed: %lu, ierrors: %lu, q_errors: %lu, matches: %u\n", total_rx, stats.ipackets, stats.imissed, stats.ierrors, stats.q_errors[0], total_matches);

    rte_eth_stats_get(sender_port, &stats);

    if (send_end_ns == 0)
        send_end_ns = ns_since_midnight();
    float elapsed_s = (send_end_ns - send_start_ns) / 1e9;
    float avg_mbps = ((stats.obytes - send_start_obytes) * (1.0 / (1024 * 1024))) / elapsed_s;
    float avg_pps = (stats.opackets - send_start_opackets) / elapsed_s;

    printf("\nAverage TX rate: %.2f pps (%.2f MB/s)\n", avg_pps, avg_mbps);
    printf("total_tx: %u, opackets: %lu, oerrors: %lu, q_opackets: %lu, total_resent: %u\n", total_tx, stats.opackets, stats.oerrors, stats.q_opackets[0], total_resent);
    printf("expected_matches: %lu\n", expected_matches);

    if (fh_log) {
        printf("Flushing timestamp log... ");
        fflush(stdout);
        flush_log();
        fclose(fh_log);
        printf("done.\n");
    }
}

void catch_int(int signo) {
    cleanup_and_exit();
    exit(0);
}

/*
 * Process a single MoldUDP message
 */
int handle_pkt(struct rte_mbuf *pkt) {
    int                l2_len;
    uint16_t           eth_type;
    struct udp_hdr    *udp_h;
    struct ipv4_hdr   *ip_h;
    struct ether_hdr  *eth_h;

    eth_h = rte_pktmbuf_mtod(pkt, struct ether_hdr *);
    eth_type = rte_be_to_cpu_16(eth_h->ether_type);
    l2_len = sizeof(*eth_h);
    if (eth_type != ETHER_TYPE_IPv4) {
        assert(0 && "Unexpected ether_type");
        return 0;
    }
    ip_h = (struct ipv4_hdr *) ((char *) eth_h + l2_len);
    if (ip_h->next_proto_id != IPPROTO_UDP) {
        assert(0 && "Unexpected ip proto");
        return 0;
    }
    udp_h = (struct udp_hdr *) ((char *) ip_h + sizeof(*ip_h));

    short dst_port = rte_be_to_cpu_16(udp_h->dst_port);
    if (dst_port != itch_port) {
        assert(0 && "Unexpected UDP port");
        return 0;
    }

    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    short msg_len, msg_count, msg_num;
    struct itch50_message *m;
    struct itch50_msg_add_order *ao;

    char *udp_payload = (char *) ip_h + sizeof(*ip_h) + sizeof(*udp_h);
    h = (struct omx_moldudp64_header *)udp_payload;
    size_t pkt_offset = sizeof(struct omx_moldudp64_header);

    msg_count = ntohs(h->MessageCount);

    for (msg_num = 0; msg_num < msg_count; msg_num++) {
        mm = (struct omx_moldudp64_message *) (udp_payload + pkt_offset);
        msg_len = ntohs(mm->MessageLength);
        m = (struct itch50_message *) (udp_payload + pkt_offset + 2);

        int expected_size = itch50_message_size(m->MessageType);
        if (unlikely(expected_size != msg_len))
            fprintf(stderr, "MessageType %c should have size %d, found %d\n", m->MessageType, expected_size, msg_len);

        if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
            ao = (struct itch50_msg_add_order *)m;
            if (matches_filter(ao)) {
                total_matches++;
                if (log_filename)
                    log_add_order(ao);
            }
            else {
                //assert(0 && "doesn't match filter");
            }
        }
        else {
            assert(0 && "not an add order");
        }

        pkt_offset += msg_len + 2;
    }

    return 0;
}

/*
 * The lcore main. This is the main thread that does the work, reading from
 * an input port and writing to an output port.
 */
static __attribute__((noreturn)) void
receiver(void)
{
	/*
	 * Check that the port is on the same NUMA node as the polling thread
	 * for best performance.
	 */
    printf("receiver using socket: %d\n", rte_eth_dev_socket_id(receiver_port));
	if (rte_eth_dev_socket_id(receiver_port) > 0 &&
			rte_eth_dev_socket_id(receiver_port) != (int)rte_socket_id())
			printf("WARNING, port %u is on remote NUMA node to "
					"polling thread (core %u).\n\tPerformance will "
					"not be optimal.\n", receiver_port, rte_lcore_id());

	printf("\nCore %u receiving packets on port %d.\n", rte_lcore_id(), receiver_port);

    struct rte_eth_stats stats;
    int i;
	for (;;) {

        struct rte_mbuf *bufs[BURST_SIZE];
        const uint16_t nb_rx = rte_eth_rx_burst(receiver_port, 0,
                bufs, BURST_SIZE);

        if (unlikely(nb_rx == 0))
            continue;

        for (i = 0; i < nb_rx; i++) {
            handle_pkt(bufs[i]);
            rte_pktmbuf_free(bufs[i]);
            total_rx++;
            if (unlikely(total_rx % print_interval_pkts == 0)) {
                rte_eth_stats_get(receiver_port, &stats);
                printf("total_rx: %u, ipackets: %lu, imissed: %lu, ierrors: %lu, q_errors: %lu, matches: %u\n", total_rx, stats.ipackets, stats.imissed, stats.ierrors, stats.q_errors[0], total_matches);
            }
        }

	}
}

size_t load_itch_msg(char *payload_buf) {

    // If we've reached the end of the file
    if (unlikely(in_buf_cur >= in_buf + in_file_size)) {
        if (send_cnt == 0)
            return 0;
        else
            in_buf_cur = in_buf; // continue from beginning of file
    }

    char *buf = in_buf_cur;

    struct omx_moldudp64_header *h = (struct omx_moldudp64_header *)(buf);
    struct omx_moldudp64_message *mm;
    size_t msg_len;
    short msg_num;
    short msg_count = rte_be_to_cpu_16(h->MessageCount);
    size_t pkt_offset = sizeof(struct omx_moldudp64_header);

    for (msg_num = 0; msg_num < msg_count; msg_num++) {
        mm = (struct omx_moldudp64_message *) (buf + pkt_offset);
        msg_len = rte_be_to_cpu_16(mm->MessageLength);
        pkt_offset += msg_len + 2;
        struct itch50_message *m = (struct itch50_message *)((char*)mm + 2);
        if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
            struct itch50_msg_add_order *ao = (struct itch50_msg_add_order *)m;
            if (matches_filter(ao))
                expected_matches++;
        }
    }

    in_buf_cur += pkt_offset;

    memcpy(payload_buf, buf, pkt_offset);

    return pkt_offset;
}

unsigned stock_prob_thresh = RAND_MAX;

size_t make_itch_msg(char *udp_payload) {
    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    short msg_len, msg_num;
    struct itch50_msg_add_order *ao;
    short msg_count = 1;

    h = (struct omx_moldudp64_header *)udp_payload;
    h->MessageCount = rte_cpu_to_be_16(msg_count);
    size_t payload_offset = sizeof(struct omx_moldudp64_header);

    for (msg_num = 0; msg_num < msg_count; msg_num++) {
        mm = (struct omx_moldudp64_message *) (udp_payload + payload_offset);
        msg_len = sizeof(struct itch50_msg_add_order);
        mm->MessageLength = rte_be_to_cpu_16(msg_len);
        ao = (struct itch50_msg_add_order *) (udp_payload + payload_offset + 2);
        ao->MessageType = ITCH50_MSG_ADD_ORDER;

        const char *stock = default_stock;
        if (rand() <= stock_prob_thresh) {
            expected_matches++;
            stock = filter_stock;
        }

        memcpy(ao->Stock, stock, STOCK_SIZE);

        payload_offset += msg_len + 2;
    }

    return payload_offset;
}

/*
 * Create a single MoldUDP message
 */
int make_pkt(struct rte_mbuf *pkt, int port) {
    struct udp_hdr    *udp_h;
    struct ipv4_hdr   *ip_h;
    struct ether_hdr  *eth_h;
    size_t pkt_size, payload_size;
    size_t ip_total_len;
    char *udp_payload;

    eth_h = rte_pktmbuf_mtod(pkt, struct ether_hdr *);
    ip_h = (struct ipv4_hdr *) ((char *) eth_h + sizeof(*eth_h));
    udp_h = (struct udp_hdr *) ((char *) ip_h + sizeof(*ip_h));
    udp_payload = (char *)udp_h + sizeof(*udp_h);

    if (in_buf != NULL)
        payload_size = load_itch_msg(udp_payload);
    else
        payload_size = make_itch_msg(udp_payload);

    if (payload_size == 0)
        return 0;

    pkt_size = sizeof(*eth_h) + sizeof(*ip_h) + sizeof(*udp_h) + payload_size;
    pkt->data_len = pkt_size;
    pkt->pkt_len = pkt_size;

    rte_eth_macaddr_get(port, &eth_h->s_addr);
    memcpy(&eth_h->d_addr, dst_mac, 6);
    eth_h->ether_type = rte_cpu_to_be_16(ETHER_TYPE_IPv4);

    ip_h->version_ihl = 0x45;
    ip_h->next_proto_id = IPPROTO_UDP;
    ip_h->src_addr = 0x09090909;
    ip_h->dst_addr = dst_addr;
    ip_total_len = pkt_size - sizeof(*eth_h);
    ip_h->total_length = rte_cpu_to_be_16(ip_total_len);
    udp_h->dst_port = rte_cpu_to_be_16(itch_port);
    udp_h->dgram_len= rte_cpu_to_be_16(payload_size);

    return pkt_size;
}

void insert_timestamp(struct rte_mbuf *pkt) {
    char *udp_payload = rte_pktmbuf_mtod(pkt, char *) + sizeof(struct ether_hdr) + sizeof(struct ipv4_hdr) + sizeof(struct udp_hdr);
    struct omx_moldudp64_header *h = (struct omx_moldudp64_header *)(udp_payload);
    struct omx_moldudp64_message *mm;
    size_t msg_len;
    struct itch50_message *m;
    struct itch50_msg_add_order *ao;
    short msg_num;
    short msg_count = rte_be_to_cpu_16(h->MessageCount);
    size_t offset = sizeof(struct omx_moldudp64_header);

    for (msg_num = 0; msg_num < msg_count; msg_num++) {
        mm = (struct omx_moldudp64_message *) (udp_payload + offset);
        msg_len = ntohs(mm->MessageLength);

        m = (struct itch50_message *)(udp_payload + offset + 2);
        if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
            ao = (struct itch50_msg_add_order *)m;
            memcpy(ao->Timestamp, (char*)&send_timestamp + 2, 6);
        }

        offset += msg_len + 2;
    }
}


/*
 * The lcore main. This is the main thread that does the work, reading from
 * an input port and writing to an output port.
 */
static void
sender(void)
{
	/*
	 * Check that the port is on the same NUMA node as the polling thread
	 * for best performance.
	 */
	if (rte_eth_dev_socket_id(sender_port) > 0 &&
			rte_eth_dev_socket_id(sender_port) != (int)rte_socket_id())
			printf("WARNING, port %u is on remote NUMA node to "
					"polling thread (core %u).\n\tPerformance will "
					"not be optimal.\n", sender_port, rte_lcore_id());

	printf("\nCore %u sending packets on port %d.\n", rte_lcore_id(), sender_port);

    // Wait 1 sec for the receiver to be ready
    sleep(1);

    struct rte_eth_stats stats;
    rte_eth_stats_get(sender_port, &stats);
    assert(stats.obytes == 0);

    struct rte_mbuf *pkts[BURST_SIZE];
    unsigned last_print = 0;
    unsigned nb_unsent = 0;
    unsigned nb_burst;


#define ENABLE_THROTTLE

#ifdef ENABLE_THROTTLE
    if (send_rate_pps != 0)
        printf("Throttling send rate to %upps\n", send_rate_pps);
#endif

    uint64_t pkts_per_period = 100000;//send_rate_pps / 10;
    if (pkts_per_period < 1) pkts_per_period = 1;
    uint64_t period_duration = pkts_per_period / (send_rate_pps / 1e9);
    double time_scale_ns = 1e9 / rte_get_tsc_hz();
    unsigned period_tx = 0;
    uint64_t period_start = 0;
    period_start = rte_rdtsc() * time_scale_ns;

    while (likely(total_tx < send_cnt || !send_cnt)) {

        // Make each packet in the burst
        for (nb_burst = nb_unsent; nb_burst < BURST_SIZE; nb_burst++) {
            pkts[nb_burst] = rte_pktmbuf_alloc(mbuf_pool);
            if (unlikely(pkts[nb_burst] == NULL))
                rte_exit(EXIT_FAILURE, "rte_pktmbuf_alloc()");
            int size = make_pkt(pkts[nb_burst], sender_port);
            if (unlikely(size == 0)) {
                nb_burst++;
                break;
            }
        }

        // Create the timestamp for all the pkts in the burst
        time_scale_ns = 1e9 / rte_get_tsc_hz();
        send_timestamp = rte_rdtsc() * time_scale_ns;
        send_timestamp = htonll(send_timestamp);
        for (uint16_t buf = 0; buf < nb_burst; buf++)
            insert_timestamp(pkts[buf]);


        if (unlikely(nb_burst == 0))
            break;

        if (unlikely(nb_burst < MIN_BURST_SIZE))
            // TODO: instead of dropping the last packets, send them one at a time
            break;

        const uint16_t nb_tx = rte_eth_tx_burst(sender_port, 0, pkts, nb_burst);

        nb_unsent = nb_burst - nb_tx;

        if (unlikely(nb_unsent > 0)) {
            // Shift unsent pkts to the front of the next burst
            uint16_t buf;
            for (buf = nb_tx; buf < nb_burst; buf++)
                pkts[buf-nb_tx] = pkts[buf];
            total_resent += nb_unsent;
        }

        total_tx += nb_tx;

        if (unlikely((total_tx - last_print) >= print_interval_pkts)) {
            last_print = total_tx;
            rte_eth_stats_get(sender_port, &stats);
            if (total_tx > 20 * 1000 * 1000 && send_start_ns == 0) {
                send_start_opackets = stats.opackets;
                send_start_obytes = stats.obytes;
                send_start_ns = ns_since_midnight();
            }
            printf("total_tx: %u, opackets: %lu, oerrors: %lu, q_opackets: %lu, total_resent: %u\n", total_tx, stats.opackets, stats.oerrors, stats.q_opackets[0], total_resent);
        }

#ifdef ENABLE_THROTTLE
        period_tx += nb_tx;
        if (unlikely(period_tx >= pkts_per_period && send_rate_pps != 0)) {
            uint64_t now;
            do {
                now = rte_rdtsc() * time_scale_ns;
            } while (now - period_start < period_duration);
            period_tx = 0;
            period_start = rte_rdtsc() * time_scale_ns;
        }
#endif
    }

    send_end_ns = ns_since_midnight();
    printf("Done.\n");
}

/*
 * Print command-line usage message.
 */
static void print_usage(const char *prgname)
{
    fprintf(stderr,
            "%s [EAL options] --"
            " [-R]          receiver only"
            " [-S]          sender only"
            " [-r pps]      limit send rate"
            " [-c int]      send count"
            " [-f file]     raw stream of ITCH messages to send"
            " [-p float]    probability (0.0->1.0) of sending specified stock symbol (default: 1.0)"
            " [-P int]      UDP port for ITCH messages (default: 1234)"
            " [-h]          help"
            "\n",
            prgname);
}

/*
 * Parse command-line parameters passed after the EAL parameters.
 */
static int parse_args(int argc, char **argv)
{
    int    rv,
           opt;
    char  *prgname = argv[0];
    float prob;

    if (getenv("ITCH_PORT") != NULL)
        itch_port = atoi(getenv("ITCH_PORT"));

    char *stock_env = getenv("ITCH_STOCK");
    if (stock_env != NULL)
        strcpy(filter_stock, stock_env);
    else
        strcpy(filter_stock, "GOOGL   ");

    while ((opt = getopt(argc, argv, "hc:f:l:r:p:P:")) != -1) {
        switch (opt) {
        case 'h':
            print_usage(prgname);
            return -1;
        case 'c':
            send_cnt = atoi(optarg);
            break;
        case 'f':
            in_filename = optarg;
            break;
        case 'l':
            log_filename = optarg;
            break;
        case 'r':
            send_rate_pps = atoi(optarg);
            break;
        case 'p':
            prob = atof(optarg);
            assert(0.0 <= prob && prob <= 1.0);
            stock_prob_thresh = prob * RAND_MAX;
            break;
        case 'P':
            itch_port = atoi(optarg);
            break;
        default:
            fprintf(stderr, "error: bad opt: -%c\n", opt);
            print_usage(prgname);
            return -1;
            break;
        }
    }
    if (optind >= 0) {
        argv[optind - 1] = prgname;
    }
    rv = optind - 1;
    optind = 0;

    if (log_filename) {
        fh_log = fopen(log_filename, "wb");
        if (!fh_log)
            error("open() log_filename");
        if (log_buffer_max_entries < 1) {
            fprintf(stderr, "Log buffer must contain at least 1 entry (%d is too few)\n", log_buffer_max_entries);
            print_usage("prog");
            exit(-1);
        }
        log_buffer = (struct log_record *)malloc(sizeof(struct log_record) * log_buffer_max_entries);
    }

    if (in_filename != NULL)
        load_send_file();

    return rv;
}

/*
 * The main function, which does initialization and calls the per-lcore
 * functions.
 */
int
main(int argc, char *argv[])
{
	unsigned nb_ports;
    unsigned lcore_id;
	uint16_t portid;

	/* Initialize the Environment Abstraction Layer (EAL). */
	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");

	argc -= ret;
	argv += ret;
    if ((ret = parse_args(argc, argv)) < 0) {
        rte_exit(EXIT_FAILURE, "invalid server parameters\n");
    }

	nb_ports = rte_eth_dev_count();
	if (nb_ports != 1 && nb_ports != 2)
		rte_exit(EXIT_FAILURE, "Error: number of ports must be one or two\n");

	/* Creates a new mempool in memory to hold the mbufs. */
	mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS * nb_ports,
		MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());

	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

	/* Initialize all ports. */
	for (portid = 0; portid < nb_ports; portid++)
		if (port_init(portid) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16 "\n",
					portid);

#if 1
    receiver_port = 0;
    sender_port = nb_ports-1;
#else
    sender_port = 0;
    receiver_port = nb_ports-1;
#endif

	if (rte_lcore_count() > 2)
		printf("\nWARNING: Too many lcores enabled. At most 2 used.\n");
    printf("Using %d cores\n", rte_lcore_count());

    signal(SIGINT, catch_int);

    RTE_LCORE_FOREACH_SLAVE(lcore_id) {
        if (rte_eal_remote_launch(sender, NULL, lcore_id) < 0)
            rte_exit(EXIT_FAILURE, "Cannot start slave core\n");
    }

    receiver();

    RTE_LCORE_FOREACH_SLAVE(lcore_id) {
        if (rte_eal_wait_lcore(lcore_id) < 0)
            rte_exit(EXIT_FAILURE, "Waiting for slave core\n");
    }

    cleanup_and_exit();

	return 0;
}

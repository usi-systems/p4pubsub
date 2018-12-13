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
#include "../src/int_udp.h"

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
#include <assert.h>

#define RX_RING_SIZE 4096
#define TX_RING_SIZE 4096

//#define NUM_MBUFS 8192
#define NUM_MBUFS 16384
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 4
// Smallest burst size supported by this NIC:
#define MIN_BURST_SIZE 4

static const struct rte_eth_conf port_conf_default = {
    .link_speeds = ETH_LINK_SPEED_10G,
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

int check_match(uint32_t switch_id, uint32_t hop_latency);
void cleanup_and_exit(void);
void catch_int(int signo);
int handle_pkt(struct rte_mbuf *pkt);

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

uint16_t sender_port;
unsigned send_rate_pps = 0;
unsigned send_cnt = 0;

int udp_port = 1234;
unsigned remaining_hop_cnt = 1;
unsigned match_nth;
uint32_t matching_switch_id = 22; // the switch_id that should match
float match_ratio = 0.01;

unsigned print_interval_pkts = 1 * 1000 * 1000;


const char dst_mac[] = {0x98, 0x03, 0x9b, 0x67, 0xf5, 0xef};
unsigned src_addr = 0x6100000a;
unsigned dst_addr = 0x6200000a;

unsigned total_tx = 0;
unsigned total_resent = 0;


void cleanup_and_exit(void) {
    struct rte_eth_stats stats;

    rte_eth_stats_get(sender_port, &stats);
    printf("\ntotal_tx: %u, ipackets: %lu, imissed: %lu, ierrors: %lu, q_errors: %lu\n", total_tx, stats.ipackets, stats.imissed, stats.ierrors, stats.q_errors[0]);
}

void catch_int(int signo) {
    (void)signo;
    cleanup_and_exit();
    exit(0);
}

unsigned pkt_cnt = 0;

int make_pkt(struct rte_mbuf *pkt, int port);

/*
 * Create a single UDP-encapsulated INT packet
 */
int make_pkt(struct rte_mbuf *pkt, int port) {
    struct udp_hdr    *udp_h;
    struct ipv4_hdr   *ip_h;
    struct ether_hdr  *eth_h;
    size_t pkt_size, payload_size;
    size_t ip_total_len;
    char *udp_payload;

    uint32_t switch_id;
    if (pkt_cnt % match_nth == 0)
        switch_id = matching_switch_id;
    else
        switch_id = 1; // receiver should not match on this
    pkt_cnt++;

    eth_h = rte_pktmbuf_mtod(pkt, struct ether_hdr *);
    ip_h = (struct ipv4_hdr *) ((char *) eth_h + sizeof(*eth_h));
    udp_h = (struct udp_hdr *) ((char *) ip_h + sizeof(*ip_h));
    udp_payload = (char *)udp_h + sizeof(*udp_h);

    size_t ofst = 0;

    struct int_probe_marker *probe = (struct int_probe_marker *)udp_payload;
    probe->marker1 = int_probe_marker1;
    probe->marker2 = int_probe_marker2;
    ofst += sizeof(struct int_probe_marker);

    struct intl4_shim *shim = (struct intl4_shim *) (udp_payload + ofst);
    bzero(shim, sizeof(struct intl4_shim));
    shim->int_type = 1;
    size_t len_bytes = sizeof(struct intl4_shim) + sizeof(struct int_header) + sizeof(struct int_switch_id) + sizeof(struct int_hop_latency) + sizeof(struct int_q_occupancy);
    shim->len = len_bytes / 4; // length in 4-byte words
    ofst += sizeof(struct intl4_shim);

    struct int_header *hdr = (struct int_header *) (udp_payload + ofst);
    bzero(hdr, sizeof(struct int_header));
    hdr->ver_rep_c_e = 1 << 4;
    hdr->remaining_hop_cnt = remaining_hop_cnt;
    hdr->instruction_mask_0007 = 11 << 4; // bits: 1011
    ofst += sizeof(struct int_header);


    struct int_switch_id *swid = (struct int_switch_id *) (udp_payload + ofst);
    swid->switch_id = htonl(switch_id);
    ofst += sizeof(struct int_switch_id);

    struct int_hop_latency *hl = (struct int_hop_latency *) (udp_payload + ofst);
    hl->hop_latency = htonl(8000);
    ofst += sizeof(struct int_hop_latency);

    struct int_q_occupancy *qo = (struct int_q_occupancy *) (udp_payload + ofst);
    qo->q_id = 1;
    qo->q_occupancy1 = 0xCC;
    qo->q_occupancy2 = 0xCC;
    qo->q_occupancy3 = 0xCC;
    ofst += sizeof(struct int_q_occupancy);

    payload_size = ofst;

    pkt_size = sizeof(*eth_h) + sizeof(*ip_h) + sizeof(*udp_h) + payload_size;
    pkt->data_len = pkt_size;
    pkt->pkt_len = pkt_size;

    rte_eth_macaddr_get(port, &eth_h->s_addr);
    memcpy(&eth_h->d_addr, dst_mac, 6);
    eth_h->ether_type = rte_cpu_to_be_16(ETHER_TYPE_IPv4);

    ip_h->version_ihl = 0x45;
    ip_h->next_proto_id = IPPROTO_UDP;
    ip_h->src_addr = src_addr;
    ip_h->dst_addr = dst_addr;
    ip_total_len = pkt_size - sizeof(*eth_h);
    ip_h->total_length = rte_cpu_to_be_16(ip_total_len);
    ip_h->time_to_live = 64;
    udp_h->dst_port = rte_cpu_to_be_16(udp_port);
    udp_h->src_port = rte_cpu_to_be_16(4321);
    udp_h->dgram_cksum = 0;
    udp_h->dgram_len = rte_cpu_to_be_16(payload_size + sizeof(struct udp_hdr));

    //printf("pkt %u size: %lu\n", pkt_cnt, pkt_size);

    return pkt_size;
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

	printf("\nCore %u (socket %u) sending packets on port %d (socket %u).\n", rte_lcore_id(), rte_socket_id(),
            sender_port, rte_eth_dev_socket_id(sender_port));

    struct rte_eth_stats stats;
    rte_eth_stats_get(sender_port, &stats);
    assert(stats.obytes == 0);

    struct rte_mbuf *pkts[BURST_SIZE];
    unsigned last_print = 0;
    unsigned nb_unsent = 0;
    unsigned nb_burst;

    sleep(2);


//#define ENABLE_THROTTLE

#ifdef ENABLE_THROTTLE
    if (send_rate_pps != 0)
        printf("Throttling send rate to %upps\n", send_rate_pps);

    uint64_t pkts_per_period = 100;//send_rate_pps / 10;
    if (pkts_per_period < 1) pkts_per_period = 1;
    uint64_t period_duration = pkts_per_period / (send_rate_pps / 1e9);
    double time_scale_ns = 1e9 / rte_get_tsc_hz();
    unsigned period_tx = 0;
    uint64_t period_start = 0;
    period_start = rte_rdtsc() * time_scale_ns;
#endif

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
            printf("total_tx: %u, opackets: %lu, oerrors: %lu, q_opackets: %lu, total_resent: %u\n", total_tx, stats.opackets, stats.oerrors, stats.q_opackets[0], total_resent);
        }

        usleep(1);

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
#else
        usleep(1);
#endif
    }

    printf("Done.\n");
}



/*
 * Print command-line usage message.
 */
static void print_usage(const char *prgname)
{
    fprintf(stderr,
            "%s [EAL options] --"
            " [-c int]      send count (default: unlimited)"
            " [-P int]      UDP port for ITCH messages (default: 1234)"
            " [-m float]    ratio of packets that should match filter (default: 0.01)"
            " [-n int]      remaining_hop_cnt header field value (default: 1)"
            " [-r pps]      limit send rate"
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

    while ((opt = getopt(argc, argv, "hc:m:n:P:r:")) != -1) {
        switch (opt) {
        case 'c':
            send_cnt = atoi(optarg);
            break;
        case 'h':
            print_usage(prgname);
            return -1;
        case 'm':
            match_ratio = atof(optarg);
            assert(0.0 <= match_ratio && match_ratio <= 1.0);
            break;
        case 'n':
            remaining_hop_cnt = atoi(optarg);
            break;
        case 'P':
            udp_port = atoi(optarg);
            break;
        case 'r':
            send_rate_pps = atoi(optarg);
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
	if (nb_ports != 1)
		rte_exit(EXIT_FAILURE, "Error: number of ports must be one (%d provided)\n", nb_ports);

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

	if (rte_lcore_count() > 2)
		printf("\nWARNING: Too many lcores enabled. At most 2 used.\n");
    printf("Using %d cores\n", rte_lcore_count());

    sender_port = 0;

    match_nth = 1/match_ratio;
    fprintf(stderr, "Every %d packets should match.\n", match_nth);

    signal(SIGINT, catch_int);

    sender();

    cleanup_and_exit();

	return 0;
}

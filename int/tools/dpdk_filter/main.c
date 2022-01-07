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

#define RX_RING_SIZE 16384
#define TX_RING_SIZE 4096

#define INT_PKT_BYTES 74

#define NUM_MBUFS 16384
#define MBUF_CACHE_SIZE 250
//#define BURST_SIZE 32
#define BURST_SIZE 16
// Smallest burst size supported by this NIC:
#define MIN_BURST_SIZE 4

static const struct rte_eth_conf port_conf_default = {
    .link_speeds = ETH_LINK_SPEED_100G,
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

uint64_t start_ns = 0;
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

uint16_t receiver_port;
unsigned num_filters = 0;
uint32_t *filter_switch_ids;

int udp_port = 1234;

int print_interval_pkts = 10 * 1000 * 1000;


const char dst_mac[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05};
unsigned dst_addr = 0x0a000002;

unsigned total_tx = 0;
unsigned total_rx = 0;
unsigned total_resent = 0;
unsigned total_matches = 0;


int check_match(uint32_t switch_id, uint32_t hop_latency) {
    if (num_filters == 0) return 1;
    for (unsigned i = 0; i < num_filters; i++)
        if (switch_id == filter_switch_ids[i] && hop_latency > 7999 && hop_latency < 8002)
            return 1;
    return 0;
}


void cleanup_and_exit(void) {
    struct rte_eth_stats stats;

    rte_eth_stats_get(receiver_port, &stats);
    float elapsed_s = (ns_since_midnight() - start_ns) / 1e9;
    float mpps = (total_rx / 1e6) / elapsed_s;

    printf("\ntotal_rx: %u, ipackets: %lu, imissed: %lu, ierrors: %lu, q_errors: %lu, matches: %u, Mpps: %f\n", total_rx, stats.ipackets, stats.imissed, stats.ierrors, stats.q_errors[0], total_matches, mpps);

    if (filter_switch_ids)
        free(filter_switch_ids);
}

void catch_int(int signo) {
    (void)signo;
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

    //size_t size = pkt->data_len;

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
    if (unlikely(dst_port != udp_port)) {
        fprintf(stderr, "udp.dst_port = %d\n", dst_port);
        assert(0 && "Unexpected UDP port");
    }

    short udp_len = rte_be_to_cpu_16(udp_h->dgram_len);
    if (unlikely(udp_len != 32 + sizeof(struct udp_hdr))) {
        fprintf(stderr, "udp.dgram_len = %d\n", udp_len);
        assert(0 && "Expected 32 bytes of INT headers");
    }
    char *udp_payload = (char *) ip_h + sizeof(*ip_h) + sizeof(*udp_h);

    size_t ofst = 0;

    struct int_probe_marker *probe = (struct int_probe_marker *)udp_payload;
    if (probe->marker1 != int_probe_marker1 || probe->marker2 != int_probe_marker2) {
        assert(0 && "< Not an INT packet >");
        return 0;
    }
    ofst += sizeof(struct int_probe_marker);
    //assert(ofst < size);

    //struct intl4_shim *shim = (struct intl4_shim *) (udp_payload + ofst);
    ofst += sizeof(struct intl4_shim);
    //assert(ofst < size);

    //struct int_header *hdr = (struct int_header *) (udp_payload + ofst);
    ofst += sizeof(struct int_header);
    //assert(ofst < size);

    struct int_switch_id *swid = (struct int_switch_id *) (udp_payload + ofst);
    ofst += sizeof(struct int_switch_id);
    //assert(ofst < size);

    struct int_hop_latency *hl = (struct int_hop_latency *) (udp_payload + ofst);
    ofst += sizeof(struct int_hop_latency);
    //assert(ofst < size);

    //struct int_q_occupancy *qo = (struct int_q_occupancy *) (udp_payload + ofst);
    ofst += sizeof(struct int_q_occupancy);

    //printf("intl4_shim\n\ttype: %u\n\tlen: %u\n", shim->int_type, shim->len);
    //printf("int_header\n\tremaining_hop_cnt: %u\n\tins_mask1: %u\n", hdr->remaining_hop_cnt, hdr->instruction_mask_0007);
    //printf("switch_id: %X\n", ntohl(swid->switch_id));
    //printf("hop_latency: %X\n", ntohl(hl->hop_latency));
    //unsigned occ = (qo->q_occupancy1 << 16) | (qo->q_occupancy2 << 8) | qo->q_occupancy3;
    //printf("q_id %d occ: %X\n\n", qo->q_id, occ);

    if (check_match(ntohl(swid->switch_id), ntohl(hl->hop_latency))) {
        total_matches++;
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

	printf("\nCore %u (socket %u) receiving packets on port %d (socket %u).\n", rte_lcore_id(), rte_socket_id(),
            receiver_port, rte_eth_dev_socket_id(receiver_port));

    double time_scale_ns = 1e9 / rte_get_tsc_hz();
    unsigned period_rx;
    unsigned last_total_rx = 0;
    uint64_t period_start, now;
    period_start = rte_rdtsc() * time_scale_ns;

    struct rte_eth_stats stats;
    int i;
	for (;;) {

        struct rte_mbuf *bufs[BURST_SIZE];
        const uint16_t nb_rx = rte_eth_rx_burst(receiver_port, 0,
                bufs, BURST_SIZE);

        if (unlikely(nb_rx == 0))
            continue;

        if (unlikely(start_ns == 0))
            start_ns = ns_since_midnight();

        for (i = 0; i < nb_rx; i++) {
            handle_pkt(bufs[i]);
            rte_pktmbuf_free(bufs[i]);
            total_rx++;
            if (unlikely(total_rx % print_interval_pkts == 0)) {
                now = rte_rdtsc() * time_scale_ns;
                period_rx = total_rx - last_total_rx;
                float elapsed_s = (now - period_start) / 1e9;
                uint64_t period_rx_mb = period_rx * INT_PKT_BYTES / (1024 * 1024);
                float mbps = 8 * period_rx_mb / elapsed_s;
                rte_eth_stats_get(receiver_port, &stats);
                printf("total_rx: %u, Mbps: %f, ipackets: %lu, imissed: %lu, ierrors: %lu, q_errors: %lu, matches: %u\n", total_rx, mbps, stats.ipackets, stats.imissed, stats.ierrors, stats.q_errors[0], total_matches);

                last_total_rx = total_rx;
                period_start = now;
            }
        }

	}
}



/*
 * Print command-line usage message.
 */
static void print_usage(const char *prgname)
{
    fprintf(stderr,
            "%s [EAL options] --"
            " [-P int]      UDP port for ITCH messages (default: 1234)"
            " [-f int]      Number of filters for packet matching (default: 0)"
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

    while ((opt = getopt(argc, argv, "f:hP:")) != -1) {
        switch (opt) {
        case 'f':
            num_filters = atoi(optarg);
            break;
        case 'h':
            print_usage(prgname);
            return -1;
        case 'P':
            udp_port = atoi(optarg);
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

    signal(SIGINT, catch_int);

    // Setup filters:
    filter_switch_ids = (uint32_t *)malloc(sizeof(uint32_t) * num_filters);
    for (unsigned i = 0; i < num_filters; i++)
        filter_switch_ids[i] = 22 + i;

    receiver_port = 0;

    (void)lcore_id; // unused
    //RTE_LCORE_FOREACH_SLAVE(lcore_id) {
    //    if (rte_eal_remote_launch((int (*)(void *))receiver, NULL, lcore_id) < 0)
    //        rte_exit(EXIT_FAILURE, "Cannot start slave core\n");
    //}
    //RTE_LCORE_FOREACH_SLAVE(lcore_id) {
    //    if (rte_eal_wait_lcore(lcore_id) < 0)
    //        rte_exit(EXIT_FAILURE, "Waiting for slave core\n");
    //}
    receiver();

    cleanup_and_exit();

	return 0;
}

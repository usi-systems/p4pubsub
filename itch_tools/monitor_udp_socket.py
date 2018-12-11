#!/usr/bin/env python

import sys, os
from datetime import datetime
import time
import argparse


def nsSinceMidnightUTC():
    return int((time.time() % 86400) * 1000000000)


def main():
    parser = argparse.ArgumentParser(description="Monitor a UDP socket's kernel memory usage (send/receive queue sizes)")
    parser.add_argument('port', help='Monitor socket with this port number',
            type=int)
    parser.add_argument('--sleep', '-t', help='Time in seconds to wait between logging',
            type=float, default=1)
    args = parser.parse_args()

    line_filter = ':%x ' % args.port

    while True:
        with open('/proc/net/udp', 'r') as f:
            found = False
            f.readline()
            for line in f:
                if line_filter not in line: continue
                ns = nsSinceMidnightUTC()
                parts = line.split()
                tx_q, rx_q = map(lambda x: int(x, 16), parts[4].split(':'))
                drops = int(parts[-1])

                print "%d\t%d\t%d\t%d" % (ns, rx_q, tx_q, drops)
                found = True
                break

            if not found:
                print "Port %d not found. Exiting." % args.port
                break

        time.sleep(args.sleep)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        try:
            sys.exit(0)
        except SystemExit as e:
            os._exit(e.code)


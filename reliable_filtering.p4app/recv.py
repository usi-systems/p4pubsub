#!/usr/bin/env python
import signal, sys, socket
import time
import argparse
from reliable_proto import *

parser = argparse.ArgumentParser(description='Send topics')
parser.add_argument('--port', '-p', help='receive topic messages on this port', type=int)
parser.add_argument('retrans_host', help='host from which to req a retrans', type=str)
parser.add_argument('retrans_port', help='UDP port for retrans req', type=int)
args = parser.parse_args()

class ReliableReceiver:

    def __init__(self, listen_port, retrans_host, retrans_port):
        self.retrans_addr = (retrans_host, retrans_port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('', listen_port))

        self.last_seq = None
        self.seq = None
        self.delivered_seq = None

    def close(self):
        self.sock.close()

    def _recv(self):
        data, addr = self.sock.recvfrom(2048)
        hdr, payload = data[:hdr_struct.size], data[hdr_struct.size:]
        topic, seq, last_seq = hdr_struct.unpack(hdr)
        return topic, payload, seq, last_seq

    def recv(self):
        while True:
            topic, payload, seq, last_seq = self._recv()

            if self.seq is None or last_seq == self.last_seq+1:
                self.seq = seq
                self.last_seq = last_seq

                if self.delivered_seq is None or self.delivered_seq < seq:
                    self.delivered_seq = seq
                    return topic, payload, seq, last_seq

            elif last_seq <= self.last_seq: # ignore old messages
                continue
            else:
                print "missing seq", self.seq+1, "to", seq
                self.last_seq = last_seq
                self.retransmitReq(self.seq+1, seq)


    def retransmitReq(self, seq_from, seq_to):
        hdr = retrans_hdr_struct.pack(seq_from, seq_to)
        self.sock.sendto(hdr, self.retrans_addr)


receiver = ReliableReceiver(args.port, args.retrans_host, args.retrans_port)

def signalHandler(signal, frame):
    receiver.close()
    sys.exit(0)
signal.signal(signal.SIGINT, signalHandler)


while True:
    topic, payload, seq, last_seq = receiver.recv()

    print "Topic: %d, seq: %d, last_seq: %d, payload: %s" % (topic, seq,
                                                            last_seq, payload)

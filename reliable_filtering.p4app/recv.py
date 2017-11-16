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
        msg_type, seq1, seq2, x = hdr_struct.unpack(hdr)
        assert msg_type in [MSG_TYPE_DATA, MSG_TYPE_MISSING]
        return msg_type, seq1, seq2, x, payload

    def recv(self):
        while True:
            msg_type, seq1, seq2, x, payload = self._recv()

            print "-> %s{seq1: %d, seq2: %d, topic: %d}" % (msgName(msg_type), seq1, seq2, x)

            if self.seq is None or seq2 == self.last_seq+1:
                self.seq = seq1
                self.last_seq = seq2

            if seq2 > self.last_seq:
                self.last_seq = seq2
                seq_from, seq_to = sorted([self.seq+1, seq1])
                self.retransmitReq(seq_from, seq_to)
                continue

            if msg_type == MSG_TYPE_DATA:
                if self.delivered_seq is None or self.delivered_seq < self.seq:
                    self.delivered_seq = seq1
                    print "        Deliver {Topic: %d, seq: %d, last_seq: %d, payload: %s}" % (x, seq1, seq2, payload)
                    return x, payload, seq1, seq2
            elif msg_type == MSG_TYPE_MISSING:
                self.retransmitReq(seq1, x)

    def retransmitReq(self, seq_from, seq_to):
        print "        <- RETRREQ{seq1: %d, seq2: %d}" % (seq_from, seq_to)
        hdr = hdr_struct.pack(MSG_TYPE_RETRANS_REQ, seq_from, seq_to, 0)
        self.sock.sendto(hdr, self.retrans_addr)


receiver = ReliableReceiver(args.port, args.retrans_host, args.retrans_port)

def signalHandler(signal, frame):
    receiver.close()
    sys.exit(0)
signal.signal(signal.SIGINT, signalHandler)


while True:
    topic, payload, seq, last_seq = receiver.recv()


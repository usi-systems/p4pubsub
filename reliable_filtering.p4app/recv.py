#!/usr/bin/env python
import signal, sys, socket
import time
import argparse
from reliable_proto import *

parser = argparse.ArgumentParser(description='Send topics')
parser.add_argument('--port', '-p', help='receive topic messages on this port', type=int)
parser.add_argument('--topic', '-t', help='only deliver messages for this topic', type=int, default=None)
parser.add_argument('retrans_host', help='host from which to req a retrans', type=str)
parser.add_argument('retrans_port', help='UDP port for retrans req', type=int)
args = parser.parse_args()

class ReliableReceiver:

    def __init__(self, listen_port, retrans_host, retrans_port, topic=None):
        self.retrans_addr = (retrans_host, retrans_port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('', listen_port))
        self.topic = topic

        self.last_seq = None
        self.seq = None
        self.delivered_seq = None

        self.msg_queue = {}

    def _queueAdd(self, global_seq, seq2, topic, payload):
        self.msg_queue[global_seq] = [seq2, topic, payload]

        if self.topic is not None and topic != self.topic:
            del self.msg_queue[global_seq]

    def _queueExpect(self, global_seq):
        if global_seq not in self.msg_queue:
            self.msg_queue[global_seq] = None

    def _queueHead(self):
        if len(self.msg_queue) == 0: return None
        seq = sorted(self.msg_queue.keys())[0]
        return seq

    def _queueAvailable(self):
        global_seq = self._queueHead()
        if global_seq is None: return None
        return self.msg_queue[global_seq] is not None

    def _queuePop(self):
        global_seq = self._queueHead()
        if global_seq is None: return None
        seq2, topic, payload = self.msg_queue[global_seq]
        del self.msg_queue[global_seq]
        return global_seq, seq2, topic, payload

    def _queueLatest(self):
        latest = None
        for seq in sorted(self.msg_queue.keys()):
            if self.msg_queue[seq] is None: break
            latest = seq
        return latest


    def close(self):
        self.sock.close()

    def _recv(self):
        data, addr = self.sock.recvfrom(2048)
        hdr, payload = data[:hdr_struct.size], data[hdr_struct.size:]
        msg_type, seq1, seq2, prev_global_seq, topic = hdr_struct.unpack(hdr)
        assert msg_type in [MSG_TYPE_DATA, MSG_TYPE_MISSING, MSG_TYPE_RETRANS]
        return msg_type, seq1, seq2, prev_global_seq, topic, payload

    def recv(self):
        while True:
            msg_type, seq1, seq2, prev_global_seq, topic, payload = self._recv()

            if self.seq is None:
                self.seq = seq1

            print "-> %s{seq1: %d, seq2: %d, seq3: %d, topic: %d}" % (
                    msgName(msg_type), seq1, seq2, prev_global_seq, topic)

            if msg_type == MSG_TYPE_DATA or msg_type == MSG_TYPE_RETRANS:
                if seq1 > self.delivered_seq:
                    self._queueAdd(seq1, seq2, topic, payload)

            if self.last_seq is not None and seq2 != self.last_seq+1:
                seq_from = self.seq+1
                if seq1 != prev_global_seq and seq1-1 < prev_global_seq:
                    seq_to = prev_global_seq
                else:
                    seq_to = seq1-1
                for seq in range(seq_from, seq_to+1):
                    if seq1 <= self.delivered_seq: continue
                    self._queueExpect(seq)
                self.retransmitReq(seq_from, seq_to)

            if self.last_seq is None or seq2 > self.last_seq:
                self.last_seq = seq2

            if msg_type == MSG_TYPE_MISSING:
                for seq in range(prev_global_seq, seq1+1):
                    self._queueExpect(seq)
                self.retransmitReq(prev_global_seq, seq1)

            latest_global_seq = self._queueLatest()
            if latest_global_seq is not None:
                self.seq = latest_global_seq

            if self._queueAvailable():
                seq1, seq2, topic, payload = self._queuePop()
                self.delivered_seq = seq1
                print "        Deliver {Topic: %d, seq: %d, last_seq: %d, payload: %s}" % (topic, seq1, seq2, payload)
                return topic, payload, seq1, seq2

    def retransmitReq(self, seq_from, seq_to):
        print "        <- RETRREQ{seq1: %d, seq2: %d}" % (seq_from, seq_to)
        hdr = hdr_struct.pack(MSG_TYPE_RETRANS_REQ, seq_to, 0, seq_from, 0)
        self.sock.sendto(hdr, self.retrans_addr)


receiver = ReliableReceiver(args.port, args.retrans_host, args.retrans_port, topic=args.topic)

def signalHandler(signal, frame):
    receiver.close()
    sys.exit(0)
signal.signal(signal.SIGINT, signalHandler)


while True:
    topic, payload, seq, last_seq = receiver.recv()


#!/usr/bin/env python
import sys, socket
import time
import signal
import threading
import argparse
import SocketServer
from reliable_proto import *
from controller_rpc import RPCClient

parser = argparse.ArgumentParser(description='Send topics')
#parser.add_argument('--topic', help='topic to send', type=int, default=1)
#parser.add_argument('--payload', help='payload to send', type=str, default=None)
parser.add_argument('--no-contr', '-n', help='disable connecting to the controller',
                     action="store_true", default=False)
parser.add_argument('--port', '-p', help='listen for retrans reqs on this port', type=int, default=4321)
parser.add_argument('dst_host', help='send to this host', type=str)
parser.add_argument('dst_port', help='send to this UDP port', type=int)
args = parser.parse_args()

class ReliableSender(threading.Thread):

    def __init__(self, listen_port, dst_host, dst_port):
        threading.Thread.__init__(self)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('', 0))
        if dst_host == '255.255.255.255':
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.dst_addr = (dst_host, dst_port)

        self.send_history = {}
        self.seq = 0

        class MyUDPHandler(SocketServer.BaseRequestHandler):
            def handle(self2):
                data = self2.request[0]
                msg_type, seq_to, _, seq_from, topic = hdr_struct.unpack(data)
                print "-> %s{seq1: %d, seq2: %d}" % (msgName(msg_type), seq_from, seq_to),
                assert msg_type == MSG_TYPE_RETRANS_REQ
                self.retransmit(seq_from, seq_to)

        self.retrans_server = SocketServer.UDPServer(('', listen_port), MyUDPHandler)

    def run(self):
        self.retrans_server.serve_forever()

    def retransmit(self, seq_from, seq_to):
        print "    retransmitting seqs", seq_from, "to", seq_to
        assert seq_from in self.send_history
        assert seq_to in self.send_history
        for seq in range(seq_from, seq_to+1):
            data = self.send_history[seq]
            self.sock.sendto(data, self.dst_addr)

    def stop(self):
        self.retrans_server.shutdown()

    def send(self, topic, payload):
        self.seq += 1
        hdr = hdr_struct.pack(MSG_TYPE_DATA, self.seq, self.seq, 0, topic)
        data = hdr + payload
        self.send_history[self.seq] = data
        self.sock.sendto(data, self.dst_addr)

class FakeCont:
    def runCmd(self, **kw): pass

if args.no_contr: cont = FakeCont()
else:             cont = RPCClient()

sender = ReliableSender(args.port, args.dst_host, args.dst_port)
sender.start()

def signalHandler(signal, frame):
    sender.stop()
    sys.exit(0)
signal.signal(signal.SIGINT, signalHandler)


sender.send(1, 'a')
cont.runCmd(cmd='table_set_default drop_ingr _drop')
sender.send(2, 'A')
cont.runCmd(cmd='table_set_default drop_ingr _nop')
sender.send(1, 'b')

cont.runCmd(cmd='table_set_default drop_egr _drop')
sender.send(2, 'B')
sender.send(1, 'c')
cont.runCmd(cmd='table_set_default drop_egr _nop')
sender.send(2, 'C')

time.sleep(0.2) # wait for some last retransmits
sender.stop()

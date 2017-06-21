#!/usr/bin/env python
import signal, sys, struct, socket
import time
import threading
from bloomfilter import BloomFilter

from netkafka import *

class Consumer:

    def __init__(self, port):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('', port))

        self.new_record_callbacks = []
        self.sender_seqs = {}
        self.subscriptions = []
        self.missing_seqs = set()
        self.repair_cnt = 0

    def onNewRecord(self, cb):
        self.new_record_callbacks.append(cb)

    def start(self):
        self.listen_thread = threading.Thread(target=self.run)
        self.listen_thread.daemon = True
        self.listen_thread.start()

    def stop(self):
        self.sock.close()

    def run(self):
        while True:
            data, addr = self.sock.recvfrom(2048)
            self.processPkt(data, addr)

    def wantBF(self, bf):
        for s in self.subscriptions:
            want = True
            for topic in s:
                if not bf.lookup(struct.pack('B', topic)):
                    want = False
                    break
            if want:
                return True
        return False

    def checkHistory(self, sender_addr, data):
        history_hdr = data[HDR_SIZE:]
        bf_size, entry_count = struct.unpack('!B B', history_hdr[:2])
        entry_size = 4 + bf_size
        entries_bin = history_hdr[2:]
        missing = []
        for i in range(entry_count):
            seq, bf_bin = struct.unpack('!I %ss' % bf_size, entries_bin[i*entry_size:i*entry_size+entry_size])
            bf = BloomFilter(bf_size * 8, 7)
            bf.load(bf_bin)
            if self.wantBF(bf) and seq not in self.sender_seqs[sender_addr]:
                missing.append(seq)

        history_hdr_size = 2 + entry_count*entry_size
        return (history_hdr_size, missing)

    def requestMissing(self, sender_addr, missing_seqs):
        self.sendNack(sender_addr, missing_seqs)

    def sendNack(self, sender_addr, missing_seqs):
        hdr = struct.pack('!B B B 4s H I', 0, 1, 0, sender_addr[0], sender_addr[1], 0)
        hdr += struct.pack('B', len(missing_seqs))
        for seq in missing_seqs:
            hdr += struct.pack('!I', seq)

        hdr += '\x00' * (HDR_SIZE - len(hdr))

        self.sock.sendto(hdr, sender_addr)


    def processPkt(self, data, addr):
        publish, nack, retrans, sender_ip, sender_port, seq = struct.unpack("!B B B 4s H I", data[:HDR_SIZE-TAG_SIZE])
        sender_addr = (socket.inet_ntoa(sender_ip), sender_port)

        if sender_addr not in self.sender_seqs: self.sender_seqs[sender_addr] = []
        self.sender_seqs[sender_addr].append(seq)
        if seq in self.missing_seqs: self.missing_seqs.remove(seq)

        tag = data[HDR_SIZE-TAG_SIZE:HDR_SIZE]
        tag = bytearray(tag)
        tag = sum(x << i*8 for i,x in enumerate(reversed(bytearray(tag))))

        if retrans:
            self.repair_cnt += 1
            if tag == 0:
                return

        history_hdr_size, missing_seqs = self.checkHistory(sender_addr, data)

        self.missing_seqs.update(missing_seqs)
        if missing_seqs: self.requestMissing(sender_addr, missing_seqs)

        payload = data[HDR_SIZE+history_hdr_size:]
        for cb in self.new_record_callbacks:
            cb(tag, payload)


last_payload_seq = None
start_time = None
msgs_received = 0
bytes_received = 0

def handleNewRecord(tag, record):
    global last_payload_seq, start_time, msgs_received, bytes_received, last_payload_seq
    if start_time is None: start_time = time.time()
    payload_seq = int(record.split(':', 1)[0])
    msgs_received += 1
    bytes_received += len(record)

    #if payload_seq > 1:
    #    assert payload_seq == last_payload_seq + 1, "Sequence (%d) should be one more than last_seq (%d)" % (payload_seq, last_payload_seq)

    last_payload_seq = payload_seq



stats_waiter = threading.Event()

def signal_handler(signal, frame):
    print "\ntotal received:", msgs_received
    if start_time and msgs_received: print "avg rate:", msgs_received / float(time.time() - start_time), "msg/s"
    print "outstanding seqs:", len(c.missing_seqs)
    print "repaired cnt:", c.repair_cnt
    stats_waiter.set()
    c.stop()
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

def stats_thread():
    interval_s = 3
    time.sleep(0.1)
    while True:
        msgs_before = msgs_received
        bytes_before = bytes_received
        if stats_waiter.wait(interval_s):
            break
        if msgs_before is None: continue
        rate = (msgs_received - msgs_before) / float(interval_s)
        mbps = (bytes_received - bytes_before) / float(interval_s)
        print "%.2f pkt/s (%.2f MB/s)" % (rate, mbps/1024/1024)

t = threading.Thread(target=stats_thread)
t.daemon = True
t.start()

c = Consumer(int(sys.argv[1]))
c.subscriptions = [[1]]
c.onNewRecord(handleNewRecord)
c.start()

while True:
    time.sleep(5)

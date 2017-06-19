#!/usr/bin/env python
import signal, sys, struct, socket
import time
import threading

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', int(sys.argv[1])))

msgs_received = 0
last_seq = None
start_time = None
record_size = 0


stats_waiter = threading.Event()

def signal_handler(signal, frame):
    print "\ntotal received:", msgs_received
    if start_time and msgs_received: print "avg rate:", msgs_received / float(time.time() - start_time), "msg/s"
    stats_waiter.set()
    s.close()
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

def stats_thread():
    interval_s = 3
    time.sleep(0.1)
    while True:
        before = msgs_received
        if stats_waiter.wait(interval_s):
            break
        if before is None: continue
        received = msgs_received - before
        rate = received / float(interval_s)
        mbps = rate * record_size
        print "%.2f pkt/s (%.2f MB/s)" % (rate, mbps/1024/1024)

t = threading.Thread(target=stats_thread)
t.daemon = True
t.start()

def receiver_thread():
    global start_time, msgs_received, record_size
    while True:
        data, addr = s.recvfrom(2048)
        if start_time is None: start_time = time.time()
        msgs_received += 1
        record = data[33:]
        record_size = len(record)

        #hdr = data[:33]
        #tag, f = struct.unpack("!32s B", hdr)
        #tag = bytearray(tag)
        #tag = sum(x << i*8 for i,x in enumerate(reversed(bytearray(tag))))

        seq = int(record.split(':', 1)[0])

        if seq > 1:
            assert seq == last_seq + 1, "Sequence (%d) should be one more than last_seq (%d)" % (seq, last_seq)

        last_seq = seq


t = threading.Thread(target=receiver_thread)
t.daemon = True
t.start()

while True:
    time.sleep(5)

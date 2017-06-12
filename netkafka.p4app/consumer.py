#!/usr/bin/env python
import signal, sys, struct, socket
import time
import threading

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', int(sys.argv[1])))

last_count = None
record_size = 0

def signal_handler(signal, frame):
    print "total received:", last_count
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

def stats_thread():
    interval_s = 5
    time.sleep(0.1)
    while True:
        before = last_count
        time.sleep(interval_s)
        if before is None: continue
        received = last_count - before
        rate = received / float(interval_s)
        mbps = rate * record_size
        print "%.2f pkt/s (%.2f MB/s)" % (rate, mbps/1024/1024)

t = threading.Thread(target=stats_thread)
t.start()

inst_num = None
while True:
    data, addr = s.recvfrom(2048)
    record = data[33:]
    record_size = len(record)

    #hdr = data[:33]
    #tag, f = struct.unpack("!32s B", hdr)
    #tag = bytearray(tag)
    #tag = sum(x << i*8 for i,x in enumerate(reversed(bytearray(tag))))

    pkt_inst_num, count = struct.unpack('!I Q', record[:12])

    if pkt_inst_num != inst_num:
        inst_num = pkt_inst_num
    else:
        assert count == last_count + 1, "Count (%d) should be one more than last_count (%d)" % (count, last_count)

    last_count = count

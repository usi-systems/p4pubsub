#!/usr/bin/env python
import socket
import SocketServer
import struct
import os

MSG_TYPE_DATA           = 1

hdr_struct = struct.Struct('!B L Q') # msg_type, topic, timestamp

if 'KAFKA_PORT' in os.environ:
    listen_port = int(os.environ['KAFKA_PORT'])
else:
    listen_port = 1234


subscriptions = {}

#subscriptions[1] = [('node95', listen_port)]
subscriptions[1] = [('10.0.1.101', listen_port)]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('', 0))

class MyUDPHandler(SocketServer.BaseRequestHandler):
    def handle(self2):
        data = self2.request[0]
        msg_type, topic, timestamp = hdr_struct.unpack(data[:hdr_struct.size])

        assert msg_type == MSG_TYPE_DATA
        assert topic in subscriptions

        for addr in subscriptions[topic]:
            sock.sendto(data, addr)

server = SocketServer.UDPServer(('', listen_port), MyUDPHandler)

try:
    server.serve_forever()
except KeyboardInterrupt:
    print "exit"

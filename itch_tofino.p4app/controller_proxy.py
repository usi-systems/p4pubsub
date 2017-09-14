#!/usr/bin/env python
import socket
import os
import sys

CONTROLLER_IPC_FILENAME = '/tmp/itch_controller.sock'

port = int(sys.argv[1])
tcp_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcp_sock.bind(('', port))
tcp_sock.listen(5)

if not os.path.exists(CONTROLLER_IPC_FILENAME):
    print "Socket file does not exist:", CONTROLLER_IPC_FILENAME
    sys.exit(1)

controller_sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
controller_sock.connect(CONTROLLER_IPC_FILENAME)

while True:
    data = ''
    try:
        conn, addr = tcp_sock.accept()
        while True:
            chunk = conn.recv(2048)
            if not chunk: break
            data += chunk
    except: break

    print addr, data

    controller_sock.send(data)
    conn.close()

controller_sock.close()
tcp_sock.close()

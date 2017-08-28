import threading
import socket
import os, os.path
import time

from appcontroller import AppController
from abstract_controller import AbstractController

CONTROLLER_IPC_FILENAME = '/tmp/camus_controller.sock'

class CustomAppController(AbstractController, AppController):

    def __init__(self, *args, **kwargs):
        AbstractController.__init__(self, *args, **kwargs)
        AppController.__init__(self, *args, **kwargs)

        self.topo, self.net = kwargs['topo'], kwargs['net']

        self.ipc_thread = threading.Thread(target=self.ipc_thread)
        self.ipc_thread.start()

        self.findHostPorts()

    def findHostPorts(self):
        self.port_for_hostname = {}
        self.port_for_ip = {}
        self.ip_for_hostname = {}
        for h in self.net.hosts:
            link = self.topo._host_links[h.name].values()[0]
            self.port_for_ip[link['host_ip']] = link['sw_port']
            self.port_for_hostname[h.name] = link['sw_port']
            self.ip_for_hostname[h.name] = link['host_ip']


    def start(self):
        AppController.start(self)

    def stop(self):
        AppController.stop(self)
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()
        self.ipc_thread.join()

    def ipc_thread(self):
        if os.path.exists(CONTROLLER_IPC_FILENAME):
          os.remove(CONTROLLER_IPC_FILENAME)

        self.sock = socket.socket( socket.AF_UNIX, socket.SOCK_DGRAM )
        self.sock.bind(CONTROLLER_IPC_FILENAME)

        print "Controller listening..."

        while True:
          data = self.sock.recv(2048)
          if not data: break
          addr_str, msg = data.split('\x00')
          host, port = addr_str.split(':')
          addr = (host, int(port))
          self.handleControlMsg(msg, addr)

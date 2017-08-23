from appcontroller import AppController

import threading
import socket
import os, os.path
import time

CONTROLLER_IPC_FILENAME = '/tmp/camus_controller.sock'

def parseNodeAddr(hint_addr, control_addr):
    parts = hint_addr.split(':')
    if parts[0] == '':
        host = control_addr[0]
    port = int(parts[1])
    return (host, port)

def strToHexInt(s):
    return ''.join(format(ord(char), '02x') for char in s)


class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)

        self.topo, self.net = kwargs['topo'], kwargs['net']

        self.ipc_thread = threading.Thread(target=self.ipc_thread)
        self.ipc_thread.start()

        self.findHostPorts()


        self.ports_for_topic = {}
        self.mgid_for_topic = {}
        self.mcnode_handle_for_mgid = {}

        self.mcast_groups = {}

        self.last_mgid = 0
        self.last_mcnoderid = -1

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

        self.sock.close()
        os.remove(CONTROLLER_IPC_FILENAME)

    def handleControlMsg(self, data, addr):
        cmd = data.split('\t')
        if cmd[0] == 'sub':
            node = parseNodeAddr(cmd[1], addr)
            topics = cmd[2:]
            self.subscribe(node, topics)
        else:
            raise Exception("Unrecognized command: " + cmd)

    def subscribe(self, node, topics):
        print "sub", node, topics
        port = self.port_for_ip[node[0]]
        commands = []
        for topic in topics:
            if topic not in self.mgid_for_topic:
                self.ports_for_topic[topic] = [port]
                self.createMcastGroup(topic, self.ports_for_topic[topic])
                commands += ['table_add topics set_mgid 0x%s => %d' %
                        (strToHexInt(topic), self.mgid_for_topic[topic])]
            else:
                self.ports_for_topic[topic].append(port)
                mgid, ports = self.mgid_for_topic[topic], self.ports_for_topic[topic]
                commands += ['mc_node_update %d %s' %
                        (self.mcnode_handle_for_mgid[mgid], ' '.join(map(str, ports)))]

        self.sendCommands(commands)

    def createMcastGroup(self, topic, ports):
        self.last_mgid += 1
        mgid = self.mgid_for_topic[topic] = self.last_mgid
        commands = ['mc_mgrp_create %d' % mgid]

        self.last_mcnoderid += 1
        commands += ['mc_node_create %d %s' % (self.last_mcnoderid, ' '.join(map(str, ports)))]
        results = self.sendCommands(commands)

        self.mcnode_handle_for_mgid[mgid] = results[-1]['handle']
        commands = ['mc_associate_node %d %d 1' % (mgid, self.mcnode_handle_for_mgid[mgid])]
        #commands = ['mc_node_associate %d %d' % (mgid, self.mcnode_handle_for_mgid[mgid])]  # XXX BMV2
        self.sendCommands(commands)


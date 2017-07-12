from appcontroller import AppController

import threading
import socket
import os, os.path
import time

CONTROLLER_IPC_FILENAME = '/tmp/itch_controller.sock'

def parseStocks(stocks_with_commas):
    return ["%-8s" % st for st in stocks_with_commas.split(',')] # pad right with spaces


class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)

        self.topo, self.net = kwargs['topo'], kwargs['net']

        self.ipc_thread = threading.Thread(target=self.ipc_thread)
        self.ipc_thread.start()


        self.stocks = {} # {stock: {mcgid: X, subscriptions: {host: mcnodeid}}}

        self.host_ports = self.findHostPorts()

        self.last_mcgid = 0
        self.last_mcnodeid = -1

    def findHostPorts(self):
        mapping = {}
        for h in self.net.hosts:
            link = self.topo._host_links[h.name].values()[0]
            mapping[link['host_ip']] = link['sw_port']
        return mapping


    def start(self):
        AppController.start(self)

        print "host_ports", self.host_ports

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
          self.handleReq(data)

        self.sock.close()
        os.remove(CONTROLLER_IPC_FILENAME)

    def handleReq(self, data):
        parts = [s.strip() for s in data.split('\t')]
        if len(parts) < 1:
            print "Malformed request:", data
            return
        cmd = parts[0]

        if cmd == 'sub': # subscribe request
            if len(parts) != 3:
                print "Malformed sub request:", data
                return

            _, host, stocks = parts
            self.subscribe(host, parseStocks(stocks))

        elif cmd == 'unsub':
            if len(parts) != 3:
                print "Malformed sub request:", data
                return

            _, host, stocks = parts
            self.unsubscribe(host, parseStocks(stocks))

    def subscribe(self, host, stocks):
        entries = []

        for stock in stocks:
            if stock not in self.stocks:
                self.last_mcgid += 1
                self.stocks[stock] = dict(mcgid=self.last_mcgid, subscriptions=dict())
                entries += ['mc_mgrp_create %d' % self.stocks[stock]['mcgid']]
                stock_binary = ''.join(format(ord(x), '02x') for x in stock)
                entries += ['table_add add_order set_mgid 0x%s => %d' % (stock_binary, self.stocks[stock]['mcgid']) ]

            self.last_mcnodeid += 1
            self.stocks[stock]['subscriptions'][host] = self.last_mcnodeid

            entries += ['mc_node_create %d %d' %
                    (self.stocks[stock]['subscriptions'][host], self.host_ports[host])]
            entries += ['mc_node_associate %d %d' %
                    (self.stocks[stock]['mcgid'], self.stocks[stock]['subscriptions'][host])]

        self.add_entries(entries=entries)

    def unsubscribe(self, host, stocks):
        for stock in stocks:
            if stock not in self.subscriptions:
                print "Cannot unsubscribe, because stock doesn't exist:", stock
                return
            if host not in self.subscriptions[stock]:
                print "Cannot unsubscribe, because host is not subscribed:", stock, host
                return
            self.subscriptions[stock].remove(host)
            # TODO: remove these MC groups and nodes from switch



from appcontroller import AppController

class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)


    def findHostPorts(self):
        mapping = {}
        for h in self.net.hosts:
            link = self.topo._host_links[h.name].values()[0]
            mapping[link['host_ip']] = link['sw_port']
        return mapping


    def start(self):
        AppController.start(self)

        results = self.sendCommands(['mc_mgrp_create 1', 'mc_node_create 0 1 2 3'])
        self.sendCommands(['mc_node_associate 1 %d' % results[-1]['handle']])

        results = self.sendCommands(['mc_mgrp_create 2', 'mc_node_create 1 1'])
        self.sendCommands(['mc_node_associate 2 %d' % results[-1]['handle']])

        results = self.sendCommands(['mc_mgrp_create 3', 'mc_node_create 2 2'])
        self.sendCommands(['mc_node_associate 3 %d' % results[-1]['handle']])

        results = self.sendCommands(['mc_mgrp_create 4', 'mc_node_create 3 3'])
        self.sendCommands(['mc_node_associate 4 %d' % results[-1]['handle']])

        results = self.sendCommands(['mc_mgrp_create 5', 'mc_node_create 4 1 2'])
        self.sendCommands(['mc_node_associate 5 %d' % results[-1]['handle']])

        results = self.sendCommands(['mc_mgrp_create 6', 'mc_node_create 5 1 3'])
        self.sendCommands(['mc_node_associate 6 %d' % results[-1]['handle']])

        results = self.sendCommands(['mc_mgrp_create 7', 'mc_node_create 6 2 3'])
        self.sendCommands(['mc_node_associate 7 %d' % results[-1]['handle']])



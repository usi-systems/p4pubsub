import random
from appcontroller import AppController
from routingscheme.routers.tz import generateConcreteRoutingConf, generateAbstractRoutingConf

class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)

    def generate_entries(self):
        random.seed(1234)

        sw_names = self.topo._port_map.keys()

        port_map = dict(self.topo._port_map)
        for sw in port_map:
            port_map[sw][sw] = 1

        #import networkx as nx
        #topo = nx.Graph()
        #for u,w in self.topo.links():
        #    if u not in sw_names or w not in sw_names: continue
        #    topo.add_edge(u, w)
        #routing_conf = generateAbstractRoutingConf(topo)

        routing_conf = generateConcreteRoutingConf(self.conf['routing_conf'], port_map)
        node_ids = routing_conf['node_ids']

        for sw in sw_names:
            lbl = routing_conf['labels'][sw]
            self.conf['parameters']['%s_label'%sw] = '%d %d %d' % lbl

        print "Node id mapping:", routing_conf['node_ids']
        print "Routing tables:", routing_conf['tables']
        print "Node labels:", routing_conf['labels']
        print "Switch port mapping:", port_map

        for sw in sw_names:
            if sw not in self.entries: self.entries[sw] = []
            self.entries[sw].append('table_set_default label _drop')
            for dst,port in routing_conf['tables'][sw].iteritems():
                self.entries[sw].append('table_add label set_port %d&&&0xffff 0&&&0 => %d 10' % (dst, port))
            self.entries[sw].append('table_add label set_port_lbl 0&&&0 %d&&&0xffff => 20' % node_ids[sw])
            for lm,port in routing_conf['tables'][sw].iteritems():
                if routing_conf['node_ids'][sw] == lm: continue
                self.entries[sw].append('table_add label set_port 0&&&0 %d&&&0xffff => %d 30' % (lm, port))

            if len(self.topo._sw_hosts[sw]) == 0: continue
            host = self.topo._sw_hosts[sw].values()[0]
            self.entries[sw].append('table_add send_frame rewrite_mac 1 => %s' % host['sw_mac'])
            self.entries[sw].append('table_add forward set_dmac 1 => %s' % host['host_mac'])
            self.entries[sw].append('table_add ipv4_port set_nhop 1 => %s' % host['host_ip'])

        # Disable strict reverse path validation:
        # https://serverfault.com/questions/163244/linux-kernel-not-passing-through-multicast-udp-packets
        for h in self.net.hosts:
            h.cmd('sysctl -n net.ipv4.conf.all.rp_filter=0')
            h.cmd('sysctl -n net.ipv4.conf.default.rp_filter=0')
            for iface in h.intfNames():
                h.cmd('sysctl -n net.ipv4.conf.%s.rp_filter=0' % iface)


import networkx as nx
import json
import random

from common import genPortMap, Packet
import routers.tz as tz
import routers.opti as opti

avg = lambda l: sum(l) / float(len(l))
avg_tbl_size = lambda tbl: avg(map(len, tbl.itervalues()))

class NetworkSim:
    def __init__(self, topology, port_map=None, default_router=None):
        self.topology = topology
        # A router takes two arguments (current node, pkt) and returns the next
        # hop this packet should go to.
        self.port_map = port_map or genPortMap(topology)
        self.rev_port_map = dict((v, dict((p, v) for v,p in pm.iteritems())) for v,pm in self.port_map.iteritems())
        self.default_router = default_router or optimalRouterFactory(topology, self.port_map)

    def send(self, pkt, router=None):
        path = []
        router = router or self.default_router
        current_hop = pkt['src']
        path.append(current_hop)
        while current_hop != pkt['dst']:
            port = router(current_hop, pkt)
            nhop = self.rev_port_map[current_hop][port]
            assert self.topology.has_edge(current_hop, nhop), "Edge not in topology: %s" % str((current_hop, nhop))
            assert nhop not in path, "Cycle in path: %s" % str(path + [nhop])
            path.append(nhop)
            current_hop = nhop

        return path

def draw(G):
    nx.draw_networkx(G, with_labels=True)
    import matplotlib.pyplot as plt
    plt.show()


def randomPackets(topo, PktClass, cnt):
    return map(lambda (a,b): PktClass(a, b), [tuple(random.sample(topo.nodes(), 2)) for _ in range(20)])

def makeTZPacketClass(labels):
    class TZPacket(Packet):
        def __init__(self, src, dst):
            Packet.__init__(self, src, dst)
            self['label'] = labels[dst]
    return TZPacket


if __name__ == '__main__':
    random.seed(1234)

    #topo = nx.read_edgelist('./as-caida20040105_small.txt', nodetype=int, delimiter='\t', comments='#')
    #nx.relabel_nodes(topo, dict([(num, 's%d'%num) for num in topo.nodes_iter()]), copy=False)

    n, m = 3,3
    topo = nx.grid_2d_graph(n, m)
    nx.relabel_nodes(topo, dict([((i,j), 's%02d'%((i*m)+j+1)) for i,j in topo.nodes_iter()]), copy=False)

    print map(list, topo.edges())
    draw(topo)

    port_map = genPortMap(topo)

    abstract_tz_routing_conf = tz.generateAbstractRoutingConf(topo)
    tz_routing_conf = tz.generateConcreteRoutingConf(abstract_tz_routing_conf, port_map)
    tzRouter = tz.generateRouterFromConf(tz_routing_conf)
    TZPacket = makeTZPacketClass(tz_routing_conf['labels'])

    opti_routing_conf = opti.generateRoutingConf(topo, port_map)
    optiRouter = opti.generateRouterFromConf(opti_routing_conf)

    with open('grid_tz_routing_conf.json', 'w') as f:
        json.dump(abstract_tz_routing_conf, f, indent=1)

    net = NetworkSim(topo, default_router=tzRouter, port_map=port_map)

    def iter_all_node_pairs():
        for u in topo.nodes_iter():
            for w in topo.nodes_iter():
                if u == w: continue
                yield (u, w)

    tz_pathlen, opti_pathlen = [], []
    for u,w in iter_all_node_pairs():
        p = TZPacket(u, w)
        tz_path = net.send(p)
        opti_path = net.send(p, router=optiRouter)
        tz_pathlen.append(len(tz_path))
        opti_pathlen.append(len(opti_path))

    print "avg tz_pathlen", avg(tz_pathlen)
    print "avg opti_pathlen", avg(opti_pathlen)
    print "diff", len(filter(lambda (a,b):a!=b, zip(tz_pathlen, opti_pathlen))) / float(len(tz_pathlen))

    #packets = randomPackets(topo, TZPacket, 20)
    #for p in packets:
    #    print
    #    print p['label']
    #    print 'tz  ', net.send(p)
    #    print 'opti', net.send(p, router=optiRouter)

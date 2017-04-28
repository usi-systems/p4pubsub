# This script simulates packet forwarding in a network.
#
# The optimal router uses tables that contain rules for every other node in the
# network (i.e. it has size n).
#
# The tzRouter uses the Thorup-Zwick compact routing scheme.
#

import networkx as nx
import random
from math import log


def draw(G):
    nx.draw_networkx(G, with_labels=True)
    import matplotlib.pyplot as plt
    plt.show()

class Packet(dict):
    def __init__(self, src, dst):
        dict.__init__(self)
        self['src'] = src
        self['dst'] = dst

def optimalRouterFactory(topo):
    tables = {}
    for v in nx.nodes_iter(topo):
        tables[v] = dict([(u, nx.shortest_path(topo, v, u)[:2][-1]) for u in nx.nodes_iter(topo)])
    avg_table_size = sum(map(len, tables.itervalues())) / float(len(tables))
    print "optimalRouter avg_table_size", avg_table_size
    router = lambda current_hop, pkt: tables[current_hop][pkt['dst']]
    return router

def tzRouterFactory(topo):
    shortest_path = lambda u,w: nx.shortest_path(topo, u, w)
    dist = lambda u,w: len(shortest_path(u, w))

    V = topo.nodes()
    n = len(V)
    q = (n / log(n)) ** (1./2)

    print "n=%d, q=%d" % (n, q)

    def sample(W):
        p = q / len(W)
        return [w for w in W if random.random() < p]

    LS = []                     # landmark set
    W = list(V)                 # nodes with large clusters

    while len(W):
        smpl = sample(W)
        if len(smpl) == 0: continue
        LS += smpl

        L = dict([(v, sorted([shortest_path(v, l) for l in LS], key=len)[0][-1]) for v in V])
        C = dict([(v, [c for c in V if dist(c, v) < dist(c, L[c]) and c!=v]) for v in V])
        W = [w for w in V if len(C[w]) > (4*n)/q]

    tables = dict()
    for v in V:
        tables[v] = dict()
        tables[v].update(dict([(l, shortest_path(v, l)[:2][-1]) for l in LS if l != v]))
        tables[v].update(dict([(c, shortest_path(v, c)[:2][-1]) for c in C[v]]))

    avg_table_size = sum(map(len, tables.itervalues())) / float(len(tables))
    print "tzRouter avg_table_size", avg_table_size

    for v in LS:
        tables[v].update(dict([(u, u) for u in nx.all_neighbors(topo, v)]))

    def router(current_hop, pkt):
        landmark, landmark_nhop, _ = pkt['label']
        if pkt['dst'] in tables[current_hop]:
            return tables[current_hop][pkt['dst']]
        elif current_hop == landmark:
            return tables[current_hop][landmark_nhop]
        else:
            return tables[current_hop][landmark]

    def labeler(v):
        return (L[v], shortest_path(L[v], v)[:2][-1], v)

    class TZPacket(Packet):
        def __init__(self, src, dst):
            assert src in V
            assert dst in V
            Packet.__init__(self, src, dst)
            self['label'] = labeler(dst)

    return (router, TZPacket)


class NetworkSim:
    def __init__(self, topology, default_router=None):
        self.topology = topology
        # A router takes two arguments (current node, pkt) and returns the next
        # hop this packet should go to.
        self.default_router = default_router or optimalRouterFactory(topology)

    def send(self, pkt, router=None):
        path = []
        router = router or self.default_router
        current_hop = pkt['src']
        path.append(current_hop)
        while current_hop != pkt['dst']:
            nhop = router(current_hop, pkt)
            assert self.topology.has_edge(current_hop, nhop), "Edge not in topology: %s" % str((current_hop, nhop))
            path.append(nhop)
            current_hop = nhop

        return path

def randomPackets(topo, cnt, PktClass):
    return map(lambda (a,b): PktClass(a, b), [tuple(random.sample(topo.nodes(), 2)) for _ in range(20)])

if __name__ == '__main__':
    random.seed(1234)
    #topo = nx.read_edgelist('./as-caida20040105_small.txt', nodetype=int, delimiter='\t', comments='#')
    topo = nx.grid_2d_graph(10, 10)
    #draw(topo)
    optiRouter = optimalRouterFactory(topo)
    tzrouter, TZPacket = tzRouterFactory(topo)
    net = NetworkSim(topo, default_router=tzrouter)

    packets = randomPackets(topo, 20, TZPacket)
    for p in packets:
        print
        print p['label']
        print 'tz  ', net.send(p)
        print 'opti', net.send(p, router=optiRouter)

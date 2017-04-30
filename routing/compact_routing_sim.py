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
import json


def draw(G):
    nx.draw_networkx(G, with_labels=True)
    import matplotlib.pyplot as plt
    plt.show()

class Packet(dict):
    def __init__(self, src, dst):
        dict.__init__(self)
        self['src'] = src
        self['dst'] = dst

def generateOptimalRoutingConf(topo, port_map):
    next_hop = lambda u,w: nx.shortest_path(topo, u, w)[:2][-1]
    tables = {}
    for v in nx.nodes_iter(topo):
        tables[v] = dict([(u, port_map[v].index(next_hop(v, u))) for u in nx.nodes_iter(topo)])
    avg_table_size = sum(map(len, tables.itervalues())) / float(len(tables))
    print "optimalRouter avg_table_size", avg_table_size
    labels = dict([(v, v) for v in nx.nodes_iter(topo)])
    routing_conf = dict(tables=tables, links=topo.edges(), labels=labels, node_ids=labels, port_map=port_map)
    return routing_conf

def generateOptiRouterFromConf(routing_conf):
    def router(current_hop, pkt):
        return routing_conf['tables'][current_hop][routing_conf['node_ids'][pkt['dst']]]
    return router


def generateTZRoutingConf(topo, port_map):
    sp_cache = dict()
    def shortest_path(u, w):
        if (u,w) not in sp_cache:
            if (w,u) in sp_cache:
                sp_cache[(u,w)] = sp_cache[(w,u)][::-1]
            else:
                sp_cache[(u,w)] = nx.shortest_path(topo, u, w)
        return sp_cache[(u,w)]
    dist = lambda u,w: len(shortest_path(u, w))
    next_hop = lambda u,w: shortest_path(u, w)[:2][-1]

    V = topo.nodes()
    n = len(V)
    q = (n / log(n)) ** (1./2)

    print "n=%d, q=%d," % (n, q),

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
    print "|LS|=%d" % len(LS)

    # assign an ID to each node v
    v_id = dict([(v, i) for i,v in enumerate(sorted(V))])

    tables = dict()
    for v in V:
        tables[v] = dict()
        tables[v][v_id[v]] = 0
        tables[v].update(dict([(v_id[l], port_map[v].index(next_hop(v, l))) for l in LS if l != v]))
        tables[v].update(dict([(v_id[c], port_map[v].index(next_hop(v, c))) for c in C[v]]))

    avg_table_size = sum(map(len, tables.itervalues())) / float(len(tables))
    print "tzRouter avg_table_size", avg_table_size

    def readable_label(v):
        return (L[v], next_hop(L[v], v), v)

    def labeler(v):
        lm = v_id[L[v]]
        return (lm, port_map[L[v]].index(next_hop(L[v], v)), v_id[v])

    labels = dict([(v, labeler(v)) for v in V])

    routing_conf = dict(tables=tables, links=topo.edges(), labels=labels, port_map=port_map, node_ids=v_id)
    return routing_conf

def generateTZRouterFromConf(routing_conf):
    tables = routing_conf['tables']
    v_id = routing_conf['node_ids']

    def router(current_hop, pkt):
        landmark, landmark_port, dst_id = pkt['label']
        if dst_id in tables[current_hop]:
            return tables[current_hop][dst_id]
        elif v_id[current_hop] == landmark:
            return landmark_port
        else:
            return tables[current_hop][landmark]

    return router

def generateTZPktClassFromConf(routing_conf):
    class TZPacket(Packet):
        def __init__(self, src, dst):
            Packet.__init__(self, src, dst)
            self['label'] = routing_conf['labels'][dst]
    return TZPacket


def genPortMap(topo):
    # the 0 (zero) port maps back to us
    return dict([(v, [v]+sorted(nx.neighbors(topo, v))) for v in topo.nodes_iter()])


class NetworkSim:
    def __init__(self, topology, port_map=None, default_router=None):
        self.topology = topology
        # A router takes two arguments (current node, pkt) and returns the next
        # hop this packet should go to.
        self.port_map = port_map or genPortMap(topology)
        self.default_router = default_router or optimalRouterFactory(topology, self.port_map)

    def send(self, pkt, router=None):
        path = []
        router = router or self.default_router
        current_hop = pkt['src']
        path.append(current_hop)
        while current_hop != pkt['dst']:
            port = router(current_hop, pkt)
            nhop = port_map[current_hop][port]
            assert self.topology.has_edge(current_hop, nhop), "Edge not in topology: %s" % str((current_hop, nhop))
            assert nhop not in path, "Cycle in path: %s" % str(path + [nhop])
            path.append(nhop)
            current_hop = nhop

        return path

def randomPackets(topo, PktClass, cnt):
    return map(lambda (a,b): PktClass(a, b), [tuple(random.sample(topo.nodes(), 2)) for _ in range(20)])


if __name__ == '__main__':
    random.seed(1234)

    #topo = nx.read_edgelist('./as-caida20040105_small.txt', nodetype=int, delimiter='\t', comments='#')
    #nx.relabel_nodes(topo, dict([(num, 's%d'%num) for num in topo.nodes_iter()]), copy=False)

    n, m = 5, 5
    topo = nx.grid_2d_graph(n, m)
    nx.relabel_nodes(topo, dict([((i,j), 's%d'%((i*m)+j)) for i,j in topo.nodes_iter()]), copy=False)

    #draw(topo)

    port_map = genPortMap(topo)

    tz_routing_conf = generateTZRoutingConf(topo, port_map)
    tzRouter = generateTZRouterFromConf(tz_routing_conf)
    TZPacket = generateTZPktClassFromConf(tz_routing_conf)

    opti_routing_conf = generateOptimalRoutingConf(topo, port_map)
    optiRouter = generateOptiRouterFromConf(opti_routing_conf)

    with open('tz_router.json', 'w') as f:
        json.dump(tz_routing_conf, f, indent=1)

    net = NetworkSim(topo, default_router=tzRouter, port_map=port_map)

    packets = randomPackets(topo, TZPacket, 20)
    for p in packets:
        print
        print p['label']
        print 'tz  ', net.send(p)
        print 'opti', net.send(p, router=optiRouter)

import networkx as nx
from math import log
import random
from common import Packet

def generateAbstractRoutingConf(topo):
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

        L = dict((v, sorted([shortest_path(v, l) for l in LS], key=len)[0][-1]) for v in V)
        C = dict((v, [c for c in V if dist(c, v) < dist(c, L[c]) and c!=v]) for v in V)
        W = [w for w in V if len(C[w]) > (4*n)/q]

    print "|LS|=%d" % len(LS)

    tables = dict()
    for v in V:
        tables[v] = dict()
        tables[v][v] = v
        tables[v].update(dict((l, next_hop(v, l)) for l in LS if l != v))
        tables[v].update(dict((c, next_hop(v, c)) for c in C[v]))

    avg_table_size = sum(map(len, tables.itervalues())) / float(len(tables))
    print "tzRouter avg_table_size", avg_table_size

    def labeler(v):
        return (L[v], next_hop(L[v], v), v)

    labels = dict([(v, labeler(v)) for v in V])

    routing_conf = dict(tables=tables, links=topo.edges(), labels=labels)
    return routing_conf

def generateConcreteRoutingConf(routing_conf, port_map):
    V = list(set(sum(map(list, routing_conf['links']), [])))

    # assign an ID to each node v
    v_id = dict((v, i) for i,v in enumerate(sorted(V)))

    tables = dict()
    for v in routing_conf['tables']:
        tables[v] = dict()
        for u,nhop in routing_conf['tables'][v].iteritems():
            tables[v][v_id[u]] = port_map[v][nhop]

    labels = dict()
    for v, (lm, nhop, v2) in routing_conf['labels'].iteritems():
        labels[v] = (v_id[lm], port_map[lm][nhop], v_id[v])

    concrete_routing_conf = dict(
        tables=tables,
        labels=labels,
        links=list(routing_conf['links']),
        node_ids=v_id)
    return concrete_routing_conf


def generateRouterFromConf(routing_conf):
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

def generatePktClassFromConf(routing_conf):
    class TZPacket(Packet):
        def __init__(self, src, dst):
            Packet.__init__(self, src, dst)
            self['label'] = routing_conf['labels'][dst]
    return TZPacket


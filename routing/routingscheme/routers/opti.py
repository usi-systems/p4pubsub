import networkx as nx

def generateRoutingConf(topo, port_map):
    next_hop = lambda u,w: nx.shortest_path(topo, u, w)[:2][-1]
    tables = {}
    for v in nx.nodes_iter(topo):
        tables[v] = dict((u, port_map[v][next_hop(v, u)]) for u in nx.nodes_iter(topo))
    labels = dict([(v, v) for v in nx.nodes_iter(topo)])
    routing_conf = dict(tables=tables, links=topo.edges(), labels=labels, node_ids=labels)
    return routing_conf

def generateRouterFromConf(routing_conf):
    def router(current_hop, pkt):
        return routing_conf['tables'][current_hop][routing_conf['node_ids'][pkt['dst']]]
    return router


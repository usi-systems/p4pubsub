def strToHexInt(s):
    return ''.join(format(ord(char), '02x') for char in s)

def parseNodeAddr(hint_addr, control_addr):
    parts = hint_addr.split(':')
    if parts[0] == '':
        host = control_addr[0]
    port = int(parts[1])
    return (host, port)

class AbstractController:

    def __init__(self, *args, **kwargs):
        self.ports_for_topic = {}
        self.mgid_for_topic = {}
        self.mcnode_handle_for_mgid = {}

        self.mcast_groups = {}

        self.last_mgid = 0
        self.last_mcnoderid = -1

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


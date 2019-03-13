from scapy.fields import ByteField, ShortField
from scapy.packet import Packet, bind_layers
from scapy.layers.inet import IP, UDP
from scapy.layers.l2 import Ether

class PosHdr(Packet):
    name = "PosHdr"
    fields_desc = [
            ShortField("id", 0),
            ShortField("x", 0),
            ShortField("y", 0),
            ShortField("speed", 0)
            ]

bind_layers(UDP, PosHdr, dport=1234)
bind_layers(UDP, PosHdr, sport=1234)

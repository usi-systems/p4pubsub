import re
import collections
import logging
logging.getLogger("scapy.runtime").setLevel(logging.ERROR)
from scapy.all import Packet, BitField

class P4Headers(dict):
    header_re = re.compile("header_type([^{]+){\s*fields\s*{([^}]+)}\s*}")

    def __init__(self, fname=None):
        with open(fname, 'r') as f:
            self._loadHeaders(f.read())

    def _loadHeaders(self, p4code):
        for m in self.header_re.findall(p4code):
            header_name = m[0].strip()
            self[header_name] = collections.OrderedDict()
            setattr(self[header_name], 'name', header_name)
            fields = m[1].split(';')
            for f in fields:
                f = f.strip()
                if not f: continue
                parts = f.split(':')
                if len(parts) != 2: continue
                field_name, field_size = parts
                self[header_name][field_name.strip()] = int(field_size.split()[0])

def p4HeaderToScapyPacket(p4header_dict):
    total_bits = sum(p4header_dict.values())
    assert total_bits % 8 == 0
    total_bytes = total_bits / 8

    pkt_fields_desc = []
    for field,size in p4header_dict.iteritems():
        pkt_fields_desc.append(BitField(field, 0, size))

    pkt_name = p4header_dict.name if hasattr(p4header_dict, 'name') else 'header'

    class PacketClass(Packet):
        MAX_LEN=total_bytes
        name=pkt_name
        fields_desc = pkt_fields_desc

    return PacketClass


if __name__ == '__main__':
    filename = "./p4src/header.p4"
    headers = P4Headers(filename)

    pkt_class = p4HeaderToScapyPacket(headers['ipv4_t'])

    field_vals = dict(
            version=2,
            ihl=1,
            diffserv=0xff,
            totalLen=0xffff,
            identification=0,
            flags=0,
            fragOffset=0,
            ttl=5,
            protocol=0,
            hdrChecksum=0,
            srcAddr=0,
            dstAddr=0)

    pkt1 = pkt_class(**field_vals)
    pkt2 = pkt_class(str(pkt1))
    assert pkt1 == pkt2

    def testHeader(h):
        pkt_class = p4HeaderToScapyPacket(headers[h])

        even = dict()
        odd = dict()

        for i,(field,size) in enumerate(headers[h].iteritems()):
            all_bits_set = (2**size)-1
            even[field] = all_bits_set if i%2 else 0
            odd[field] = 0 if i%2 else all_bits_set

        packed_even = str(pkt_class(**even))
        unpacked_even = pkt_class(packed_even)
        packed_odd = str(pkt_class(**odd))
        unpacked_odd = pkt_class(packed_odd)

        for f in headers[h]:
            assert even[f] == getattr(unpacked_even, f), "%s.%s expected %x but got %x" % (h, f, even[f], unpacked_even[f])
            assert odd[f] == getattr(unpacked_odd, f), "%s.%s expected %x but got %x" % (h, f, odd[f], unpacked_odd[f])

    for h in headers:
        testHeader(h)

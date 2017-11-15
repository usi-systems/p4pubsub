import struct

hdr_struct = struct.Struct('!L L L') # topic, seq, last_seq
retrans_hdr_struct = struct.Struct('!L L') # seq_from, seq_to

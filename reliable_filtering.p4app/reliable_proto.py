import struct

MSG_TYPE_DATA           = 1
MSG_TYPE_MISSING        = 2
MSG_TYPE_RETRANS_REQ    = 3
MSG_TYPE_RETRANS        = 4

def msgName(msg_type):
    if msg_type == MSG_TYPE_DATA:
        return "MSG"
    elif msg_type == MSG_TYPE_MISSING:
        return "MISSING"
    elif msg_type == MSG_TYPE_RETRANS_REQ:
        return "RETRREQ"
    elif msg_type == MSG_TYPE_RETRANS:
        return "RETRANS"
    else:
        raise Exception("Unrecognized msg_type")

hdr_struct = struct.Struct('!B L L L L') # msg_type, global_seq, port_seq, global_seq2, topic

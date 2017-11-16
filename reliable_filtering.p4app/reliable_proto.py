import struct

MSG_TYPE_DATA           = 1
MSG_TYPE_MISSING        = 2
MSG_TYPE_RETRANS_REQ    = 3

def msgName(msg_type):
    if msg_type == MSG_TYPE_DATA:
        return "MSG"
    elif msg_type == MSG_TYPE_MISSING:
        return "MISSING"
    elif msg_type == MSG_TYPE_RETRANS_REQ:
        return "RETRREQ"
    else:
        raise Exception("Unrecognized msg_type")

hdr_struct = struct.Struct('!B L L L') # msg_type, seq1, seq2, topic

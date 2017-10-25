import struct

LR_NUM_XWAY  = 2
LR_NUM_SEG   = 100
LR_NUM_LANES = 3
LR_NUM_DIRS  = 2

LR_MSG_POS_REPORT = 0

position_report_struct = struct.Struct('!B H L B B B B B')

class LRMsg(dict):
    def __str__(self):
        return '{' + ', '.join(["%s: %s" % (str(k), str(v)) for k,v in self.iteritems()]) + '}'

    def loc(self):
        """ Get location refered to by this message, if any. """
        return dict((k, self[k]) for k in ['xway', 'seg', 'dir', 'lane'])



def packPosReport(time=0, vid=0, spd=0, xway=0,
                        lane=0, dir=0, seg=0):
    assert 0 <= time and time <= 10799
    assert 0 <= spd and spd <= 100
    assert 0 <= lane and lane <= 4
    assert 0 <= dir and dir <= 1
    assert 0 <= seg and seg <= 99
    data = position_report_struct.pack(LR_MSG_POS_REPORT, time, vid, spd, xway, lane, dir, seg)
    return data

def unpackPosReport(data):
    msg_type, time, vid, spd, xway, lane, dir, seg = position_report_struct.unpack(data)
    assert msg_type == LR_MSG_POS_REPORT
    d = LRMsg(time=time, vid=vid, spd=spd,
                xway=xway, lane=lane, dir=dir, seg=seg)
    return d

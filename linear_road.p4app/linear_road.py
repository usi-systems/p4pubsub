import struct

LR_NUM_XWAY  = 2
LR_NUM_SEG   = 100
LR_NUM_LANES = 3
LR_NUM_DIRS  = 2

LR_MSG_POS_REPORT       = 0
LR_MSG_ACCIDENT_ALERT   = 1

msg_type_struct = struct.Struct('!B')
position_report_struct = struct.Struct('!B H L B B B B B')
accident_alert_struct = struct.Struct('!B H L H B')

def locId(loc):
    return tuple(loc[k] for k in ['xway', 'seg', 'dir', 'lane'])

class LRMsg(dict):
    name = 'LRMsg'
    pretty_exclude_keys = []

    def __str__(self):
        kv_strs = ["%s: %s" % (str(k), str(v)) for k,v in self.iteritems() if k not in self.pretty_exclude_keys]
        return '%s{%s}' % (self.name, ', '.join(kv_strs))

    def loc(self):
        """ Get location refered to by this message, if any. """
        return dict((k, self[k]) for k in ['xway', 'seg', 'dir', 'lane'])


class PosReport(LRMsg):
    name = 'Pos'
    pretty_exclude_keys = ['msg_type']

class AccidentAlert(LRMsg):
    name = 'Acc'
    pretty_exclude_keys = ['msg_type']


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
    d = PosReport(msg_type=msg_type, time=time, vid=vid, spd=spd,
                xway=xway, lane=lane, dir=dir, seg=seg)
    return d

def unpackAccidentAlert(data):
    msg_type, time, vid, emit, seg = accident_alert_struct.unpack(data)
    assert msg_type == LR_MSG_ACCIDENT_ALERT
    d = AccidentAlert(msg_type=msg_type, time=time, vid=vid, emit=emit, seg=seg)
    return d

def unpackLRMsg(data):
    msg_type, = msg_type_struct.unpack(data[0])
    if msg_type == LR_MSG_POS_REPORT:
        return unpackPosReport(data)
    elif msg_type == LR_MSG_ACCIDENT_ALERT:
        return unpackAccidentAlert(data)
    else:
        raise Exception("Unrecognized msg type: %d" % msg_type)

class LRException(Exception):
    pass

class LRModel:

    def __init__(self, num_xway=LR_NUM_XWAY, num_seg=LR_NUM_SEG):
        self.num_xway = num_xway
        self.num_seg = num_seg

        self.position_reports = {}
        self.stopped_state = {}
        self.last_time = None

    def newMsg(self, msg):
        if isinstance(msg, PosReport):
            self._newPos(msg)
        elif isinstance(msg, AccidentAlert):
            self._newAccidentAlert(msg)

        self.last_time = msg['time']

    def _newPos(self, pr):
        if pr['vid'] not in self.position_reports:
            self.position_reports[pr['vid']] = []
        self.position_reports[pr['vid']].append(pr)

        if pr['spd'] == 0:
            self._addStopped(pr)
        elif pr['spd'] > 0:
            self._rmStopped(pr)

    def _newAccidentAlert(self, al):
        vid, seg = al['vid'], al['seg']
        if vid not in self.position_reports:
            raise LRException("PosReports not yet received for VID")

        latest_pr = self.position_reports[vid][-1]

        stopped_seg = self._accidentAhead(latest_pr)

        if stopped_seg is None:
            raise LRException("Unwarranted AccidentAlert")

        if seg != stopped_seg:
            raise LRException("Wrong AccidentAlert seg")

    def _rmStopped(self, pr):
        lid = locId(pr)
        if lid not in self.stopped_state: return
        if pr['vid'] not in self.stopped_state[lid]: return
        _, prev_set = self.stopped_state[lid][-1]
        new_set = prev_set.difference(set([pr['vid']]))
        self.stopped_state[lid].append((pr['time'], new_set))

    def _addStopped(self, pr):
        lid = locId(pr)
        if lid not in self.stopped_state:
            self.stopped_state[lid] = [(pr['time'], set([pr['vid']]))]
        else:
            _, prev_set = self.stopped_state[lid][-1]
            new_set = prev_set.union(set([pr['vid']]))
            self.stopped_state[lid].append((pr['time'], new_set))

    def _accidentAhead(self, pr):
        """ Return an upcoming seg with an accident, or None """
        time = pr['time']
        xway, start_seg, dir, lane = locId(pr)
        end_seg = min(start_seg+4, self.num_seg)
        for seg in range(start_seg, end_seg+1):
            lid = (xway, seg, dir, lane)
            stopped_sets = self.getStopped(lid)
            accident_sets = filter(lambda ss: len(ss) > 1, stopped_sets)
            if len(accident_sets) > 0:
                return seg
        return None

    def getStopped(self, loc_or_lid):
        """ Returns a list of VID sets for the latest time"""
        if type(loc_or_lid) == tuple:
            lid = loc_or_lid
        else:
            locId(loc_or_lid)

        if lid not in self.stopped_state: return set()
        latest_time = self.stopped_state[lid][-1][0]
        stopped_sets = []
        for time, vid_set in self.stopped_state[lid]:
            if time == latest_time: stopped_sets.append(vid_set)
        return stopped_sets

    def getStoppedUnion(self, loc_or_lid):
        """ Returns the set off all VIDs for the latest time """
        return set.union(*self.getStopped(loc_or_lid))


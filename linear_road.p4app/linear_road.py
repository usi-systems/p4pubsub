LR_ENTRY_LANE   = 0
LR_EXIT_LANE    = 4

LR_NUM_XWAY  = 2
LR_NUM_SEG   = 100
LR_NUM_LANES = 3
LR_NUM_DIRS  = 2

LR_MSG_POS_REPORT           = 0
LR_MSG_ACCNT_BAL_REQ        = 2
LR_MSG_EXPENDITURE_REQ      = 3
LR_MSG_TRAVEL_ESTIMATE_REQ  = 4
LR_MSG_TOLL_NOTIFICATION    = 10
LR_MSG_ACCIDENT_ALERT       = 11
LR_MSG_ACCNT_BAL            = 12
LR_MSG_EXPENDITURE_REPORT   = 13
LR_MSG_TRAVEL_ESTIMATE      = 14

def locId(loc):
    return tuple(loc[k] for k in ['xway', 'seg', 'dir', 'lane'])

def Loc(*args, **kw):
    loc = {}

    assert len(args) == 0 or len(args) == 1
    if len(args) == 1:
        msg = args[0]
        for k in ['xway', 'seg', 'dir', 'lane']: loc[k] = msg[k]

    for k,v in kw.iteritems():
        if v is None:
            if k in loc: del loc[k]
        else:
            loc[k] =v
    return loc

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

class TollNotification(LRMsg):
    name = 'Toll'
    pretty_exclude_keys = ['msg_type']

class AccntBalReq(LRMsg):
    name = 'BalReq'
    pretty_exclude_keys = ['msg_type']

class AccntBal(LRMsg):
    name = 'Bal'
    pretty_exclude_keys = ['msg_type']

class ExpenditureReq(LRMsg):
    name = 'ExpReq'
    pretty_exclude_keys = ['msg_type']

class ExpenditureReport(LRMsg):
    name = 'ExpRep'
    pretty_exclude_keys = ['msg_type']

class TravelEstimate(LRMsg):
    name = 'Est'
    pretty_exclude_keys = ['msg_type']

class TravelEstimateReq(LRMsg):
    name = 'EstReq'
    pretty_exclude_keys = ['msg_type']


class LRException(Exception):
    pass

class LRModel:

    def __init__(self, num_xway=LR_NUM_XWAY, num_seg=LR_NUM_SEG):
        self.num_xway = num_xway
        self.num_seg = num_seg

        self.seg_volume = {}
        self.position_reports = {}
        self.stopped_state = {}
        self.last_time = None

    def newMsg(self, msg):
        if isinstance(msg, PosReport):
            self._newPos(msg)
        elif isinstance(msg, AccidentAlert):
            self._newAccidentAlert(msg)
        elif isinstance(msg, TollNotification):
            self._newTollNotification(msg)
        else:
            raise LRException("Unrecognized message type")

        self.last_time = msg['time']

    def _newPos(self, pr):
        if pr['vid'] not in self.position_reports:
            self.position_reports[pr['vid']] = []

        # TODO: check that a toll is received after entering new seg

        if pr['spd'] == 0:
            self._addStopped(pr)
        elif pr['spd'] > 0:
            self._rmStopped(pr)

        self._updateVol(pr)

        self.position_reports[pr['vid']].append(pr)


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

    def _newTollNotification(self, tn):
        vid = tn['vid']
        if vid not in self.position_reports:
            raise LRException("PosReports not yet received for VID")

        latest_pr = self.position_reports[vid][-1]

        if len(self.position_reports[vid]) > 1:
            latest_pr2 = self.position_reports[vid][-2]
            # Should only be emitted on entering a new segment
            if latest_pr['seg'] == latest_pr2['seg']:
                raise LRException("Unwarranted TollNotification: already in seg")

        # Should not be emitted if in exit lane
        if latest_pr['lane'] == LR_EXIT_LANE:
            raise LRException("Unwarranted TollNotification: in exit lane")

        # Should not be emitted if there's an accident
        if self.hasAccident(latest_pr):
            raise LRException("Unwarranted TollNotification: accident in seg")

    def _updateVol(self, pr):
        time, vid = pr['time'], pr['vid']

        if len(self.position_reports[vid]) > 0:
            prev_pr = self.position_reports[vid][-1]
            if prev_pr['seg'] != pr['seg']: # entered new seg
                self._incVol(time, prev_pr['seg'], -1)
                self._incVol(time, pr['seg'],      +1)
        else:
            self._incVol(time, pr['seg'],      +1)


    def _incVol(self, time, seg, inc):
        if seg not in self.seg_volume:
            self.seg_volume[seg] = []

        prev_vol = 0
        if len(self.seg_volume[seg]) > 0:
            prev_vol = self.seg_volume[seg][-1][1]

        new_vol = prev_vol + inc
        assert new_vol >= 0
        self.seg_volume[seg].append((time, new_vol))

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
            if self.hasAccident(lid):
                return seg
        return None

    def hasAccident(self, loc_or_lid):
        stopped_sets = self.getStopped(loc_or_lid)
        for ss in stopped_sets:
            if len(ss) > 1:
                return True
        return False

    def getStopped(self, loc_or_lid):
        """ Returns a list of VID sets for the latest time in this seg"""
        if type(loc_or_lid) == tuple:
            lid = loc_or_lid
        else:
            lid = locId(loc_or_lid)

        stopped_sets = []
        for lane in range(1, 4):
            lid = (lid[0], lid[1], lid[2], lane)
            if lid not in self.stopped_state: continue
            latest_time = self.stopped_state[lid][-1][0]
            for time, vid_set in self.stopped_state[lid]:
                if time == latest_time: stopped_sets.append(vid_set)
        return stopped_sets

    def getStoppedUnion(self, loc_or_lid):
        """ Returns the set off all VIDs for the latest time """
        return set.union(*self.getStopped(loc_or_lid))


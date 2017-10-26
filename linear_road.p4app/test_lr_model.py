from linear_road import LRModel, PosReport, AccidentAlert, LRException

lrm = LRModel()

lrm.newMsg(PosReport(time=1, vid=1, xway=1, seg=8, dir=0, lane=1, spd=0))
assert lrm.getStoppedUnion((1, 8, 0, 1)) == set([1])

lrm.newMsg(PosReport(time=2, vid=2, xway=1, seg=8, dir=0, lane=1, spd=0))
assert lrm.getStoppedUnion((1, 8, 0, 1)) == set([1, 2])

lrm.newMsg(PosReport(time=3, vid=3, xway=1, seg=8, dir=0, lane=1, spd=10))
lrm.newMsg(AccidentAlert(time=3, vid=3, seg=8))

try:
    lrm.newMsg(AccidentAlert(time=3, vid=4, seg=9))
    assert False, "should not get here; an assertion should have been thrown"
except LRException as e:
    assert e.message == "PosReports not yet received for VID", "Unexpected exception: %s" % e

try:
    lrm.newMsg(AccidentAlert(time=3, vid=3, seg=9))
    assert False, "should not get here; an assertion should have been thrown"
except LRException as e:
    assert e.message == "Wrong AccidentAlert seg", "Unexpected exception: %s" % e

lrm.newMsg(PosReport(time=4, vid=4, xway=1, seg=9, dir=0, lane=1, spd=10))
try:
    lrm.newMsg(AccidentAlert(time=4, vid=4, seg=8))
    assert False, "should not get here; an assertion should have been thrown"
except LRException as e:
    assert e.message == "Unwarranted AccidentAlert", "Unexpected exception: %s" % e

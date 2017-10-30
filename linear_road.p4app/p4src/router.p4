#include <tofino/intrinsic_metadata.p4>
#include <tofino/constants.p4>
#include "header.p4"
#include "parser.p4"

action _drop() {
    drop();
}

action _nop() {
}

action set_nhop(nhop_ipv4, port) {
    modify_field(ipv4.dstAddr, nhop_ipv4);
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
}

table ipv4_lpm {
    reads {
        ipv4.dstAddr : lpm;
    }
    actions {
        set_nhop;
        _drop;
    }
    size: 1024;
}

action set_dmac(dmac) {
    modify_field(ethernet.dstAddr, dmac);
}

table forward {
    reads {
        ipv4.dstAddr: exact;
    }
    actions {
        set_dmac;
        _drop;
    }
    size: 512;
}


action rewrite_mac(smac) {
    modify_field(ethernet.srcAddr, smac);
}

table send_frame {
    reads {
        eg_intr_md.egress_port: exact;
    }
    actions {
        rewrite_mac;
        _drop;
    }
    size: 256;
}

// XXX VID is used as index into registers
// XXX we don't support vehicles leaving and re-entering
#define MAX_VID 512

register v_seq_reg { // seq number of pos_report for this vehicle
  width: 32;
  instance_count: MAX_VID;
}

register v_valid_reg {
  width: 1;
  instance_count: MAX_VID;
}

register v_spd_reg {
  width: 8;
  instance_count: MAX_VID;
}

register v_xway_reg {
  width: 8;
  instance_count: MAX_VID;
}

register v_lane_reg {
  width: 3;
  instance_count: MAX_VID;
}

register v_seg_reg {
  width: 8;
  instance_count: MAX_VID;
}

register v_dir_reg {
  width: 1;
  instance_count: MAX_VID;
}

register v_ewma_spd_reg {
  width: 8;
  instance_count: MAX_VID;
}

register v_accnt_bal_reg { // sum of tolls
  width: 32;
  instance_count: MAX_VID;
}


register v_same_loc_reg {
  width: 4;
  instance_count: MAX_VID;
}


#define LR_NUM_XWAY    2
#define LR_NUM_SEG     100
#define LR_NUM_LANE   3
#define LR_NUM_DIR    2

#define STOPPED_IDX(xway, seg, dir, lane) \
    (((xway) * (LR_NUM_SEG * LR_NUM_DIR * LR_NUM_LANE)) + \
     ((seg) * LR_NUM_DIR * LR_NUM_LANE) + \
     ((dir) * LR_NUM_LANE) + \
     (lane))

#define DIRSEG_IDX(xway, seg, dir) \
    (((xway) * (LR_NUM_SEG * LR_NUM_DIR)) + \
     ((seg) * LR_NUM_DIR) + \
     (dir))



// XXX this has to be updated manually, because the macro is not expanded
//#define NUM_STOPPED_CELLS (LR_NUM_XWAY * (LR_NUM_SEG * LR_NUM_DIR * LR_NUM_LANE))
#define NUM_STOPPED_CELLS 1200

register stopped_cnt_reg {
  width: 4;
  instance_count: NUM_STOPPED_CELLS;
}


// XXX this has to be updated manually, because the macro is not expanded
//#define NUM_TOLL_LOC LR_NUM_XWAY * LR_NUM_SEG * LR_NUM_DIR
#define NUM_DIRSEG 400

register seg_vol_reg {
  width: 8;
  instance_count: NUM_DIRSEG;
}


header_type accident_meta_t {
    fields {
        cur_stp_cnt: 8;
        prev_stp_cnt: 8;
        accident_seg: 8;
        has_accident_ahead: 1;
    }
}
metadata accident_meta_t accident_meta;

header_type v_state_metadata_t {
    fields {
        seq: 32;
        new: 1; // new vehicle
        new_seg: 1; // are we in a new seg now? i.e. v_state.prev_seg != pos_report.seg
        prev_spd: 8; // state from previous pos_report
        prev_xway: 8;
        prev_lane: 3;
        prev_seg: 8;
        prev_dir: 1;
        prev_same_loc: 3;
        // Each bit represents no change from the previous pos_report.
        // 111 means four consecutive pos_reports at the same loc
#define STOPPED_LOC 7
        same_loc: 3;
        ewma_spd: 8;
    }
}
metadata v_state_metadata_t v_state;

header_type seg_metadata_t {
    fields {
        vol: 8;
        prev_vol: 8; // vol in the previous seg
    }
}
metadata seg_metadata_t seg_meta;

header_type stopped_metadata_t {
    fields {
        seg0l1: 8;
        seg0l2: 8;
        seg0l3: 8;
        seg1l1: 8;
        seg1l2: 8;
        seg1l3: 8;
        seg2l1: 8;
        seg2l2: 8;
        seg2l3: 8;
        seg3l1: 8;
        seg3l2: 8;
        seg3l3: 8;
        seg4l1: 8;
        seg4l2: 8;
        seg4l3: 8;
        seg0_ord: 8; // OR of all the lanes in this seg
        seg1_ord: 8;
        seg2_ord: 8;
        seg3_ord: 8;
        seg4_ord: 8;
    }
}
metadata stopped_metadata_t stopped_ahead;

action do_update_pos_state() {
    // Load the state for the vehicle's previous location
    register_read(v_state.seq, v_seq_reg, pos_report.vid);
    add_to_field(v_state.seq, 1);
    register_read(v_state.new, v_valid_reg, pos_report.vid);
    modify_field(v_state.new, ~v_state.new);
    register_read(v_state.prev_spd, v_spd_reg, pos_report.vid);
    register_read(v_state.prev_xway, v_xway_reg, pos_report.vid);
    register_read(v_state.prev_lane, v_lane_reg, pos_report.vid);
    register_read(v_state.prev_seg, v_seg_reg, pos_report.vid);
    register_read(v_state.prev_dir, v_dir_reg, pos_report.vid);

    // Overwrite the previous location state with the current
    register_write(v_seq_reg, pos_report.vid, v_state.seq);
    register_write(v_valid_reg, pos_report.vid, 1);
    register_write(v_spd_reg, pos_report.vid, pos_report.spd);
    register_write(v_xway_reg, pos_report.vid, pos_report.xway);
    register_write(v_lane_reg, pos_report.vid, pos_report.lane);
    register_write(v_seg_reg, pos_report.vid, pos_report.seg);
    register_write(v_dir_reg, pos_report.vid, pos_report.dir);
}
table update_pos_state {
    actions { do_update_pos_state; }
}

action set_new_seg() {
    modify_field(v_state.new_seg, 1);
}
table update_new_seg {
    actions { set_new_seg; }
}

action set_ewma_spd() {
    modify_field(v_state.ewma_spd, pos_report.spd);
    register_write(v_ewma_spd_reg, pos_report.vid, v_state.ewma_spd);
}

#define EWMA_A 25
#define EWMA(avg, x) ((avg * (100 - EWMA_A)) + (x * EWMA_A)) / 100

action calc_ewma_spd() {
    register_read(v_state.ewma_spd, v_ewma_spd_reg, pos_report.vid);
    modify_field(v_state.ewma_spd, EWMA(v_state.ewma_spd, pos_report.spd));
    register_write(v_ewma_spd_reg, pos_report.vid, v_state.ewma_spd);
}

table update_ewma_spd {
    reads { v_state.new: exact; }
    actions {
        set_ewma_spd;           // 1
        calc_ewma_spd;          // 0
    }
    size: 2;
}

action do_loc_not_changed() {
    register_read(v_state.prev_same_loc, v_same_loc_reg, pos_report.vid);
    modify_field(v_state.same_loc, v_state.prev_same_loc | (1 << (v_state.seq % 3)));
    register_write(v_same_loc_reg, pos_report.vid, v_state.same_loc);
}
table loc_not_changed {
    actions { do_loc_not_changed; }
}

action do_loc_changed() {
    register_read(v_state.prev_same_loc, v_same_loc_reg, pos_report.vid);
    register_write(v_same_loc_reg, pos_report.vid, 0);
}
table loc_changed {
    actions { do_loc_changed; }
}

action load_vol() {
    register_read(seg_meta.vol, seg_vol_reg,
            DIRSEG_IDX(pos_report.xway, pos_report.seg, pos_report.dir));
}

// only called for new vehicles, as there's no previous vol to dec
action load_and_inc_vol() {
    load_vol();
    add_to_field(seg_meta.vol, 1);
    register_write(seg_vol_reg,
            DIRSEG_IDX(pos_report.xway, pos_report.seg, pos_report.dir),
            seg_meta.vol);
}

// called for existing vehicles, because there's a previous vol to dec
action load_and_inc_and_dec_vol() {
    load_and_inc_vol();
    register_read(seg_meta.prev_vol, seg_vol_reg,
            DIRSEG_IDX(v_state.prev_xway, v_state.prev_seg, v_state.prev_dir));
    subtract_from_field(seg_meta.prev_vol, 1);
    register_write(seg_vol_reg,
            DIRSEG_IDX(v_state.prev_xway, v_state.prev_seg, v_state.prev_dir),
            seg_meta.prev_vol);
}


table update_vol_state {
    reads {
        v_state.new: exact;
        v_state.new_seg: exact;
    }
    actions {
        load_vol;                   // 0 0
        load_and_inc_vol;           // 1 1
        load_and_inc_and_dec_vol;   // 0 1
    }
    size: 4;
}

action do_load_stopped_ahead() {
    // XXX HW: can't read this many regs per stage.
    // Load the count of stopped vehicles ahead
    register_read(stopped_ahead.seg0l1, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg, pos_report.dir, 1));
    register_read(stopped_ahead.seg0l2, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg, pos_report.dir, 2));
    register_read(stopped_ahead.seg0l3, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg, pos_report.dir, 3));

    register_read(stopped_ahead.seg1l1, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+1, pos_report.dir, 1));
    register_read(stopped_ahead.seg1l2, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+1, pos_report.dir, 2));
    register_read(stopped_ahead.seg1l3, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+1, pos_report.dir, 3));

    register_read(stopped_ahead.seg2l1, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+2, pos_report.dir, 1));
    register_read(stopped_ahead.seg2l2, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+2, pos_report.dir, 2));
    register_read(stopped_ahead.seg2l3, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+2, pos_report.dir, 3));

    register_read(stopped_ahead.seg3l1, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+3, pos_report.dir, 1));
    register_read(stopped_ahead.seg3l2, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+3, pos_report.dir, 2));
    register_read(stopped_ahead.seg3l3, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+3, pos_report.dir, 3));

    register_read(stopped_ahead.seg4l1, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+4, pos_report.dir, 1));
    register_read(stopped_ahead.seg4l2, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+4, pos_report.dir, 2));
    register_read(stopped_ahead.seg4l3, stopped_cnt_reg,
                STOPPED_IDX(pos_report.xway, pos_report.seg+4, pos_report.dir, 3));

    // OR the stopped count in each seg
    modify_field(stopped_ahead.seg0_ord,
                stopped_ahead.seg0l1 | stopped_ahead.seg0l2 | stopped_ahead.seg0l3);
    modify_field(stopped_ahead.seg1_ord,
                stopped_ahead.seg1l1 | stopped_ahead.seg1l2 | stopped_ahead.seg1l3);
    modify_field(stopped_ahead.seg2_ord,
                stopped_ahead.seg2l1 | stopped_ahead.seg2l2 | stopped_ahead.seg2l3);
    modify_field(stopped_ahead.seg3_ord,
                stopped_ahead.seg3l1 | stopped_ahead.seg3l2 | stopped_ahead.seg3l3);
    modify_field(stopped_ahead.seg4_ord,
                stopped_ahead.seg4l1 | stopped_ahead.seg4l2 | stopped_ahead.seg4l3);
}
table load_stopped_ahead {
    actions { do_load_stopped_ahead; }
}

action do_dec_prev_stopped() {
    // Load stopped cnt for the previous loc:
    register_read(accident_meta.prev_stp_cnt, stopped_cnt_reg, STOPPED_IDX(
                v_state.prev_xway,
                v_state.prev_seg,
                v_state.prev_dir,
                v_state.prev_lane));
    // Decrement the count:
    register_write(stopped_cnt_reg, STOPPED_IDX(
                v_state.prev_xway,
                v_state.prev_seg,
                v_state.prev_dir,
                v_state.prev_lane),
            accident_meta.prev_stp_cnt - 1
            );
}
table dec_prev_stopped {
    actions { do_dec_prev_stopped; }
}

action do_inc_stopped() {
    // Load the current stopped count for this loc:
    register_read(accident_meta.cur_stp_cnt, stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg,
                pos_report.dir,
                pos_report.lane));
    // Increment the stopped count:
    register_write(stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg,
                pos_report.dir,
                pos_report.lane),
            accident_meta.cur_stp_cnt + 1
            );
}
table inc_stopped {
    actions { do_inc_stopped; }
}

action set_accident_meta(ofst) {
    modify_field(accident_meta.accident_seg, pos_report.seg + ofst);
    modify_field(accident_meta.has_accident_ahead, 1);
}

table check_accidents {
    reads {
        stopped_ahead.seg0_ord: range;
        stopped_ahead.seg1_ord: range;
        stopped_ahead.seg2_ord: range;
        stopped_ahead.seg3_ord: range;
        stopped_ahead.seg4_ord: range;
    }
    actions {
        set_accident_meta;
    }
    size: 8;
}


#define CALC_TOLL(basetoll, cars) (base_toll * (cars - 50) * (cars - 50))

header_type toll_metadata_t {
    fields {
        toll: 16;
        has_toll: 1;
        bal: 32;
    }
}
metadata toll_metadata_t toll_meta;

action issue_toll(base_toll) {
    modify_field(toll_meta.has_toll, 1);
    modify_field(toll_meta.toll, CALC_TOLL(base_toll, seg_meta.vol));

    // Update the account balance
    register_read(toll_meta.bal, v_accnt_bal_reg, pos_report.vid);
    add_to_field(toll_meta.bal, toll_meta.toll);
    register_write(v_accnt_bal_reg, pos_report.vid, toll_meta.bal);

}

// XXX we should explain that these parameters are configurable at runtime
table check_toll {
    reads {
        v_state.new_seg: exact;                     // if the car entered a new seg
        v_state.ewma_spd: range;                    // and its spd < 40
        seg_meta.vol: range;                        // and the |cars| in seg > 50
        accident_meta.has_accident_ahead: exact;    // and no accident ahead
    }
    actions {
        issue_toll;
    }
    size: 1;
}

action do_load_accnt_bal() {
    register_read(toll_meta.bal, v_accnt_bal_reg, accnt_bal_req.vid);
}
table load_accnt_bal {
    actions { do_load_accnt_bal; }
}

control ingress {
    if (valid(ipv4)) {
        if (valid(pos_report)) {
            apply(update_pos_state);

            if (v_state.new == 1 or
                v_state.prev_seg != pos_report.seg) {
                apply(update_new_seg);
            }

            apply(update_vol_state);
            apply(update_ewma_spd);

            if (pos_report.xway == v_state.prev_xway and
                pos_report.seg == v_state.prev_seg and
                pos_report.dir == v_state.prev_dir and
                pos_report.lane == v_state.prev_lane) {
                apply(loc_not_changed);
            }
            else {
                apply(loc_changed);
            }

            if (v_state.prev_same_loc == STOPPED_LOC and    // it was stopped
                v_state.same_loc != STOPPED_LOC             // but it's moved
                ) {
                apply(dec_prev_stopped);             // then dec stopped vehicles for prev loc
            }

            if (v_state.prev_same_loc != STOPPED_LOC and   // it wasn't stopped before
                v_state.same_loc == STOPPED_LOC            // but is stopped now
                ) {
                apply(inc_stopped);                 // then inc stopped vehicles for this loc
            }

            apply(load_stopped_ahead);

            apply(check_accidents);

            apply(check_toll);

        }
        else if (valid(accnt_bal_req)) {
            apply(load_accnt_bal);
        }

        apply(ipv4_lpm);
        apply(forward);
    }
}

header_type egress_metadata_t {
    fields {
        recirculate: 1;
    }
}
metadata egress_metadata_t accident_egress_meta;
metadata egress_metadata_t toll_egress_meta;
metadata egress_metadata_t accnt_bal_egress_meta;

header standard_metadata_t standard_metadata;

field_list alert_e2e_fl {
    accident_meta;
    accident_egress_meta;
}

action accident_alert_e2e(mir_ses) {
    modify_field(accident_egress_meta.recirculate, 1);
    clone_egress_pkt_to_egress(mir_ses, alert_e2e_fl);
}

action make_accident_alert() {
    modify_field(lr_msg_type.msg_type, LR_MSG_ACCIDENT_ALERT);

    add_header(accident_alert);
    modify_field(accident_alert.time, pos_report.time);
    modify_field(accident_alert.vid, pos_report.vid);
    modify_field(accident_alert.seg, accident_meta.accident_seg);

    remove_header(pos_report);

    modify_field(ipv4.totalLen, 38);
    modify_field(udp.length_, 18);
    modify_field(udp.checksum, 0);
}

table send_accident_alert {
    reads {
        accident_meta.has_accident_ahead: exact;
        accident_egress_meta.recirculate: exact;
    }
    actions {
        accident_alert_e2e;
        make_accident_alert;
    }
}

field_list toll_e2e_fl {
    toll_meta;
    toll_egress_meta;
    v_state;
}

action toll_notification_e2e(mir_ses) {
    modify_field(toll_egress_meta.recirculate, 1);
    clone_egress_pkt_to_egress(mir_ses, toll_e2e_fl);
}

action make_toll_notification() {
    modify_field(lr_msg_type.msg_type, LR_MSG_TOLL_NOTIFICATION);

    add_header(toll_notification);
    modify_field(toll_notification.time, pos_report.time);
    modify_field(toll_notification.vid, pos_report.vid);
    modify_field(toll_notification.spd, v_state.ewma_spd);
    modify_field(toll_notification.toll, toll_meta.toll);

    remove_header(pos_report);

    modify_field(ipv4.totalLen, 40);
    modify_field(udp.length_, 20);
    modify_field(udp.checksum, 0);
}

table send_toll_notification {
    reads {
        toll_meta.has_toll: exact;
        toll_egress_meta.recirculate: exact;
    }
    actions {
        toll_notification_e2e;
        make_toll_notification;
    }
}

field_list accnt_bal_e2e_fl {
    toll_meta;
    accnt_bal_egress_meta;
}

action accnt_bal_e2e(mir_ses) {
    modify_field(accnt_bal_egress_meta.recirculate, 1);
    clone_egress_pkt_to_egress(mir_ses, accnt_bal_e2e_fl);
}

action make_accnt_bal() {
    modify_field(lr_msg_type.msg_type, LR_MSG_ACCNT_BAL);

    add_header(accnt_bal);
    modify_field(accnt_bal.time, accnt_bal_req.time);
    modify_field(accnt_bal.vid, accnt_bal_req.vid);
    modify_field(accnt_bal.qid, accnt_bal_req.qid);
    modify_field(accnt_bal.bal, toll_meta.bal);

    remove_header(accnt_bal_req);

    modify_field(ipv4.totalLen, 43);
    modify_field(udp.length_, 23);
    modify_field(udp.checksum, 0);
}

table send_accnt_bal {
    reads {
        accnt_bal_egress_meta.recirculate: exact;
    }
    actions {
        accnt_bal_e2e;
        make_accnt_bal;
    }
}

control egress {
    if (valid(ipv4)) {
        if (valid(pos_report)) {
            apply(send_accident_alert);
            apply(send_toll_notification);
        }
        else if (valid(accnt_bal_req)) {
            apply(send_accnt_bal);
        }
        apply(send_frame);
    }
}

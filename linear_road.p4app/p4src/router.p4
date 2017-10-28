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

// XXX we don't support vehicles leaving and re-entering
#define MAX_VID 32

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
        new: 1; // new vehicle
        new_seg: 1; // are we in a new seg now? i.e. v_state.prev_seg != pos_report.seg
        prev_spd: 8; // state from previous pos_report
        prev_xway: 8;
        prev_lane: 3;
        prev_seg: 8;
        prev_dir: 1;
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
    register_read(v_state.new, v_valid_reg, pos_report.vid);
    modify_field(v_state.new, ~v_state.new);
    register_read(v_state.prev_spd, v_spd_reg, pos_report.vid);
    register_read(v_state.prev_xway, v_xway_reg, pos_report.vid);
    register_read(v_state.prev_lane, v_lane_reg, pos_report.vid);
    register_read(v_state.prev_seg, v_seg_reg, pos_report.vid);
    register_read(v_state.prev_dir, v_dir_reg, pos_report.vid);

    // Overwrite the previous location state with the current
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
    }
}
metadata toll_metadata_t toll_meta;

action issue_toll(base_toll) {
    modify_field(toll_meta.has_toll, 1);
    modify_field(toll_meta.toll, CALC_TOLL(base_toll, seg_meta.vol));
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

            if (v_state.new == 0 and
                v_state.prev_spd == 0 and                   // it was stopped
                (pos_report.spd != 0 or                     // but it's moving now
                 (v_state.prev_lane != pos_report.lane) or  // or it changed lanes
                 (v_state.prev_seg != pos_report.seg)       // or it changed seg
                )) {
                apply(dec_prev_stopped);             // then dec stopped vehicles for prev loc
            }

            // XXX divergence from spec: we say a car is stopped if spd=0
            if ((v_state.new == 1 and                     // it's a new vehicle and it's stopped
                        pos_report.spd == 0) or
                (pos_report.spd == 0 and                  // it's stopped
                (v_state.prev_spd > 0 or                  // and it was moving
                 v_state.prev_lane != pos_report.lane or  // or it entered a new lane
                 v_state.prev_seg != pos_report.seg))     // or it entered a new seg
                    ) {
                apply(inc_stopped);                 // then inc stopped vehicles for this loc
            }

            apply(load_stopped_ahead);

            apply(check_accidents);

            apply(check_toll);
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

control egress {
    if (valid(ipv4)) {
        if (valid(pos_report)) {
            apply(send_accident_alert);
            apply(send_toll_notification);
        }
        apply(send_frame);
    }
}

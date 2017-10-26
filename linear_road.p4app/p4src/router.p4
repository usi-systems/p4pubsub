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


#define LR_NUM_XWAY    2
#define LR_NUM_SEG     100
#define LR_NUM_LANES   3
#define LR_NUM_DIRS    2

#define STOPPED_IDX(xway, seg, dir, lane) \
    (((xway) * (LR_NUM_SEG * LR_NUM_DIRS * LR_NUM_LANES)) + \
     ((seg) * LR_NUM_DIRS * LR_NUM_LANES) + \
     ((dir) * LR_NUM_LANES) + \
     (lane))


// XXX this has to be updated manually, because the macro is not expanded
//#define NUM_STOPPED_CELLS (LR_NUM_XWAY * (LR_NUM_SEG * LR_NUM_DIRS * LR_NUM_LANES))
#define NUM_STOPPED_CELLS 1200

register stopped_cnt_reg {
  width: 4;
  instance_count: NUM_STOPPED_CELLS;
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

header_type v_prev_metadata_t {
  fields {
    isvalid: 1;
    spd: 8;
    xway: 8;
    lane: 3;
    seg: 8;
    dir: 1;
  }
}
metadata v_prev_metadata_t v_prev;

header_type accident_metadata_t {
  fields {
    seg0: 8;
    seg1: 8;
    seg2: 8;
    seg3: 8;
    seg4: 8;
  }
}
metadata accident_metadata_t accident_ahead;

action do_update_state() {
    // Load the state for the vehicle's previous location
    register_read(v_prev.isvalid, v_valid_reg, pos_report.vid);
    register_read(v_prev.spd, v_spd_reg, pos_report.vid);
    register_read(v_prev.xway, v_xway_reg, pos_report.vid);
    register_read(v_prev.lane, v_lane_reg, pos_report.vid);
    register_read(v_prev.seg, v_seg_reg, pos_report.vid);
    register_read(v_prev.dir, v_dir_reg, pos_report.vid);

    // Overwrite the previous location state with the current
    register_write(v_valid_reg, pos_report.vid, 1);
    register_write(v_spd_reg, pos_report.vid, pos_report.spd);
    register_write(v_xway_reg, pos_report.vid, pos_report.xway);
    register_write(v_lane_reg, pos_report.vid, pos_report.lane);
    register_write(v_seg_reg, pos_report.vid, pos_report.seg);
    register_write(v_dir_reg, pos_report.vid, pos_report.dir);
}
table update_state {
    actions { do_update_state; }
}

action do_load_stopped_ahead() {
    // Load the count of stopped vehicles ahead
    register_read(accident_ahead.seg0, stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg,
                pos_report.dir,
                pos_report.lane));
    register_read(accident_ahead.seg1, stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg+1,
                pos_report.dir,
                pos_report.lane));
    register_read(accident_ahead.seg2, stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg+2,
                pos_report.dir,
                pos_report.lane));
    register_read(accident_ahead.seg3, stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg+3,
                pos_report.dir,
                pos_report.lane));
    register_read(accident_ahead.seg4, stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg+4,
                pos_report.dir,
                pos_report.lane));
}
table load_stopped_ahead {
    actions { do_load_stopped_ahead; }
}

action do_dec_prev_stopped() {
    // Load stopped cnt for the previous loc:
    register_read(accident_meta.prev_stp_cnt, stopped_cnt_reg, STOPPED_IDX(
                v_prev.xway,
                v_prev.seg,
                v_prev.dir,
                v_prev.lane));
    // Decrement the count:
    register_write(stopped_cnt_reg, STOPPED_IDX(
                v_prev.xway,
                v_prev.seg,
                v_prev.dir,
                v_prev.lane),
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

field_list no_fields {
    accident_meta.accident_seg;
}

action set_accident_meta(ofst) {
    modify_field(accident_meta.accident_seg, pos_report.seg + ofst);
    modify_field(accident_meta.has_accident_ahead, 1);
}

table check_accidents {
    reads {
        accident_ahead.seg0: range;
        accident_ahead.seg1: range;
        accident_ahead.seg2: range;
        accident_ahead.seg3: range;
        accident_ahead.seg4: range;
    }
    actions {
        set_accident_meta;
    }
    size: 8;
}

control ingress {
    if (valid(ipv4)) {
        if (valid(pos_report)) {
            apply(update_state);

            if (v_prev.isvalid == 1 and
                v_prev.spd == 0 and                  // it was stopped
                (pos_report.spd != 0 or              // but it's moving now
                 (v_prev.lane != pos_report.lane) or // or it changed lanes
                 (v_prev.seg != pos_report.seg)      // or it changed seg
                )) {
                apply(dec_prev_stopped);             // then dec stopped vehicles for prev loc
            }

            if ((v_prev.isvalid == 0 and            // it's a new vehicle and it's stopped
                        pos_report.spd == 0) or
                (pos_report.spd == 0 and            // it's stopped
                (v_prev.spd > 0 or                  // and it was moving
                 v_prev.lane != pos_report.lane or  // or it entered a new lane
                 v_prev.seg != pos_report.seg))     // or it entered a new seg
                    ) {
                apply(inc_stopped);                 // then inc stopped vehicles for this loc
            }

            apply(load_stopped_ahead);

            apply(check_accidents);                 // check for accidents
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
metadata egress_metadata_t egress_metadata;

header standard_metadata_t standard_metadata;

field_list e2e_fl {
    accident_meta;
    egress_metadata;
}

action accident_alert_e2e(mir_ses) {
    modify_field(egress_metadata.recirculate, 1);
    clone_egress_pkt_to_egress(mir_ses, e2e_fl);
}

action make_accident_alert() {
    modify_field(lr_msg_type.msg_type, 1);

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
        egress_metadata.recirculate: exact;
    }
    actions {
        accident_alert_e2e;
        make_accident_alert;
    }
}

control egress {
    if (valid(ipv4)) {
        if (valid(pos_report)) {
            apply(send_accident_alert);
        }
        apply(send_frame);
    }
}

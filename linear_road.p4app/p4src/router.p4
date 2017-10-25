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
    modify_field(udp.checksum, 0);
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
    ((xway * (LR_NUM_SEG * LR_NUM_DIRS * LR_NUM_LANES)) + \
     (seg * LR_NUM_DIRS * LR_NUM_LANES) + \
     (dir * LR_NUM_LANES) + \
     lane)


// XXX this has to be updated manually, because the macro is not expanded
//#define NUM_STOPPED_CELLS (LR_NUM_XWAY * (LR_NUM_SEG * LR_NUM_DIRS * LR_NUM_LANES))
#define NUM_STOPPED_CELLS 1200

register stopped_cnt_reg {
  width: 4;
  instance_count: NUM_STOPPED_CELLS;
}


header_type lr_tmp_meta_t {
    fields {
        tmp: 8;
    }
}
metadata lr_tmp_meta_t lr_tmp;

header_type v_prev_metadata_t {
  fields {
    isvalid: 1;
    spd: 8;
    xway: 8;
    lane: 3;
    seg: 8;
    dir: 1;
    lane_stp_cnt: 3;
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
    register_read(v_prev.lane_stp_cnt, stopped_cnt_reg, STOPPED_IDX(
                v_prev.xway,
                v_prev.seg,
                v_prev.dir,
                v_prev.lane));

    // Overwrite the previous location state with the current
    register_write(v_valid_reg, pos_report.vid, 1);
    register_write(v_spd_reg, pos_report.vid, pos_report.spd);
    register_write(v_xway_reg, pos_report.vid, pos_report.xway);
    register_write(v_lane_reg, pos_report.vid, pos_report.lane);
    register_write(v_seg_reg, pos_report.vid, pos_report.seg);
    register_write(v_dir_reg, pos_report.vid, pos_report.dir);

    // Load the count of stopped vehicles ahead
}

table update_state {
    actions { do_update_state; }
}

action dec_prev_stopped() {
    register_write(stopped_cnt_reg, STOPPED_IDX(
                v_prev.xway,
                v_prev.seg,
                v_prev.dir,
                v_prev.lane),
            v_prev.lane_stp_cnt - 1
            );
}
table unstopped {
    actions {
        dec_prev_stopped;
    }
    size: 1;
}

action inc_stopped() {
    register_read(lr_tmp.tmp, stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg,
                pos_report.dir,
                pos_report.lane));
    register_write(stopped_cnt_reg, STOPPED_IDX(
                pos_report.xway,
                pos_report.seg,
                pos_report.dir,
                pos_report.lane),
            lr_tmp.tmp + 1
            );
}
table stopped {
    actions {
        inc_stopped;
    }
    size: 1;
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
                apply(unstopped);
            }

            if ((v_prev.isvalid == 0 and pos_report.spd == 0) or
                (pos_report.spd == 0 and            // it's stopped
                (v_prev.spd > 0 or                  // and it was moving
                 v_prev.lane != pos_report.lane or  // or it changed lane
                 v_prev.seg != pos_report.seg))
                    ) {
                apply(stopped);
            }
        }

        apply(ipv4_lpm);
        apply(forward);
    }
}

control egress {
    if (valid(ipv4)) {
        apply(send_frame);
    }
}

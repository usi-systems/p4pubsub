#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>


// This does not fit. It tries to do three SHA1 rounds per gress. Maybe it will
// fit if we only do two rounds.


// *********************************
//            HEADERS
// *********************************

header_type sha_t {
    fields {
        i: 8;
        a: 32;
        b: 32;
        c: 32;
        d: 32;
        e: 32;
    }
}

header_type words_t {
    fields {
        w0: 32;
        w1: 32;
        w2: 32;
    }
}

header_type words2_t {
    fields {
        w3: 32;
        w4: 32;
        w5: 32;
        w6: 32;
        w7: 32;
        w8: 32;
        w9: 32;
        w10: 32;
        w11: 32;
        w12: 32;
        w13: 32;
        w14: 32;
        w15: 32;
        w16: 32;
        w17: 32;
        w18: 32;
    }
}



// *********************************
//            PARSER
// *********************************

parser start {
    return parse_sha;
}

header_type meta_t {
    fields {
        tmp1: 32;
        tmp2: 32;
        tmp3: 32;
        tmp4: 32;
        tmp5: 32;
        tmp6: 32;
        tmp7: 32;
    }
}
metadata meta_t meta;

header sha_t sha;
header words_t words;
header words2_t words2;

parser parse_sha {
    extract(sha);
    extract(words);
    return select(sha.i) {
        64 mask 64: ingress;
        default: parse_words;
    }
}

parser parse_words {
    extract(words2);
    return ingress;
}

// *********************************
//            INGRESS
// *********************************

action nop() { }
action _drop() { drop(); }

action r1_a1_all() {
    shift_left(meta.tmp3, sha.a, 5);          // a<<5
    shift_right(meta.tmp4, sha.a, 27);        // a>>27
    add_to_field(sha.e, words.w0);            // e + wi
}
action r2_a1_all() {
    shift_left(meta.tmp3, sha.a, 5);          // a<<5
    shift_right(meta.tmp4, sha.a, 27);        // a>>27
    add_to_field(sha.e, words.w1);            // e + wi
}
action r3_a1_all() {
    shift_left(meta.tmp3, sha.a, 5);          // a<<5
    shift_right(meta.tmp4, sha.a, 27);        // a>>27
    add_to_field(sha.e, words.w2);            // e + wi
}

action a1A() {
    bit_and(meta.tmp1, sha.b, sha.c);         // b&c
    bit_andca(meta.tmp2, sha.b, sha.d);       // ~b&d
}
action a1B() {
    bit_xor(meta.tmp1, sha.b, sha.c);         // b^c
}
action a1C() {
    bit_and(meta.tmp1, sha.b, sha.c);         // b&c
    bit_and(meta.tmp2, sha.b, sha.d);         // b&d
}

action a2_all(k) {
    add_to_field(sha.e, k);                   // e + wi + k
    bit_or(meta.tmp3, meta.tmp3, meta.tmp4);  // a<<<5 = a<<5 | a>>27
}
action a2A() {
    bit_or(meta.tmp1, meta.tmp1, meta.tmp2);  // f <- b&c | ~b&d
}
action a2B() {
    bit_xor(meta.tmp1, meta.tmp1, sha.d);     // f <- b^c^d
}
action a2C() {
    bit_or(meta.tmp1, meta.tmp1, meta.tmp2);  // b&c | b&d
    bit_and(meta.tmp2, sha.c, sha.d);         // c&d
}

action a3_all() {
    add_to_field(sha.e, meta.tmp3);           // e + k + wi + a<<<5
    shift_left(meta.tmp3, sha.b, 30);         // b<<30
    shift_right(meta.tmp4, sha.b, 2);         // b>>2
}
action a3C() {
    bit_or(meta.tmp1, meta.tmp1, meta.tmp2);  // f <- b&c | b&d | c&d
}

action a4_all() {
    modify_field(sha.e, sha.d);               // e <- d
    modify_field(sha.d, sha.c);               // d <- c
    bit_or(sha.c, meta.tmp3, meta.tmp4);      // c <- b<<<30 = b<<30 | b>>2
    modify_field(sha.b, sha.a);               // b <- a
    add(sha.a, meta.tmp2, meta.tmp1);         // a <- e + k + wi + a<<<5 + f
    add_to_field(sha.i, 1);
}


table r1_t1_all { actions { r1_a1_all; } default_action: r1_a1_all; }
table r1_t1 { reads { sha.i: exact; } actions { a1A; a1B; a1C; } size: 80; }
table r1_t2_all { reads { sha.i: exact; } actions { a2_all; } size: 80; }
table r1_t2 { reads { sha.i: exact; } actions { a2A; a2B; a2C; } size: 80; }
table r1_t3_all { actions { a3_all; } default_action: a3_all; }
table r1_t3 { reads { sha.i: exact; } actions { a3C; } size: 80; }
table r1_t4_all { actions { a4_all; } default_action: a4_all; }

table r2_t1_all { actions { r2_a1_all; } default_action: r2_a1_all; }
table r2_t1 { reads { sha.i: exact; } actions { a1A; a1B; a1C; } size: 80; }
table r2_t2_all { reads { sha.i: exact; } actions { a2_all; } size: 80; }
table r2_t2 { reads { sha.i: exact; } actions { a2A; a2B; a2C; } size: 80; }
table r2_t3_all { actions { a3_all; } default_action: a3_all; }
table r2_t3 { reads { sha.i: exact; } actions { a3C; } size: 80; }
table r2_t4_all { actions { a4_all; } default_action: a4_all; }

table r3_t1_all { actions { r3_a1_all; } default_action: r3_a1_all; }
table r3_t1 { reads { sha.i: exact; } actions { a1A; a1B; a1C; } size: 80; }
table r3_t2_all { reads { sha.i: exact; } actions { a2_all; } size: 80; }
table r3_t2 { reads { sha.i: exact; } actions { a2A; a2B; a2C; } size: 80; }
table r3_t3_all { actions { a3_all; } default_action: a3_all; }
table r3_t3 { reads { sha.i: exact; } actions { a3C; } size: 80; }
table r3_t4_all { actions { a4_all; } default_action: a4_all; }

action ext1_a1() {
    bit_xor(meta.tmp5, words.w0, words.w2);     // w0 ^ w2
    bit_xor(meta.tmp6, words2.w8, words2.w13);  // w8 ^ w13
}
action ext1_a2() {
    bit_xor(meta.tmp7, meta.tmp5, meta.tmp6);  // w0 ^ w2 ^ w8 ^ w13
}
action ext1_a3() {
    shift_left(meta.tmp5, meta.tmp7, 1);       // w16<<1
    shift_right(meta.tmp6, meta.tmp7, 31);     // w16>>31
}
action ext1_a4() {
    bit_or(words2.w16, meta.tmp5, meta.tmp6);   // w16 <- w0 ^ w2 ^ w8 ^ w13 >>> 1
}

action ext2_a1() {
    bit_xor(meta.tmp5, words.w1, words2.w3);     // w1 ^ w3
    bit_xor(meta.tmp6, words2.w9, words2.w14);  // w9 ^ w14
}
action ext2_a2() {
    bit_xor(meta.tmp7, meta.tmp5, meta.tmp6);  // w1 ^ w3 ^ w9 ^ w14
}
action ext2_a3() {
    shift_left(meta.tmp5, meta.tmp7, 1);       // w17<<1
    shift_right(meta.tmp6, meta.tmp7, 31);     // w17>>31
}
action ext2_a4() {
    bit_or(words2.w17, meta.tmp5, meta.tmp6);   // w17 <- w1 ^ w3 ^ w9 ^ w14 >>> 1
}

action ext3_a1() {
    bit_xor(meta.tmp5, words.w2, words2.w4);     // w2 ^ w4
    bit_xor(meta.tmp6, words2.w10, words2.w15);  // w10 ^ w15
}
action ext3_a2() {
    bit_xor(meta.tmp7, meta.tmp5, meta.tmp6);  // w2 ^ w4 ^ w10 ^ w15
}
action ext3_a3() {
    shift_left(meta.tmp5, meta.tmp7, 1);       // w18<<1
    shift_right(meta.tmp6, meta.tmp7, 31);     // w18>>31
}
action ext3_a4() {
    bit_or(words2.w18, meta.tmp5, meta.tmp6);   // w18 <- w2 ^ w4 ^ w10 ^ w15 >>> 1
    remove_header(words);
}

table ext1_t1 { actions { ext1_a1; } default_action: ext1_a1; }
table ext1_t2 { actions { ext1_a2; } default_action: ext1_a2; }
table ext1_t3 { actions { ext1_a3; } default_action: ext1_a3; }
table ext1_t4 { actions { ext1_a4; } default_action: ext1_a4; }
table ext2_t1 { actions { ext2_a1; } default_action: ext2_a1; }
table ext2_t2 { actions { ext2_a2; } default_action: ext2_a2; }
table ext2_t3 { actions { ext2_a3; } default_action: ext2_a3; }
table ext2_t4 { actions { ext2_a4; } default_action: ext2_a4; }
table ext3_t1 { actions { ext3_a1; } default_action: ext3_a1; }
table ext3_t2 { actions { ext3_a2; } default_action: ext3_a2; }
table ext3_t3 { actions { ext3_a3; } default_action: ext3_a3; }
table ext3_t4 { actions { ext3_a4; } default_action: ext3_a4; }

control ingress {
    apply(r1_t1_all);
    apply(r1_t1);
    apply(r1_t2_all);
    apply(r1_t2);
    apply(r1_t3_all);
    apply(r1_t3);
    apply(r1_t4_all);

    apply(r2_t1_all);
    apply(r2_t1);
    apply(r2_t2_all);
    apply(r2_t2);
    apply(r2_t3_all);
    apply(r2_t3);
    apply(r2_t4_all);

    apply(r3_t1_all);
    apply(r3_t1);
    apply(r3_t2_all);
    apply(r3_t2);
    apply(r3_t3_all);
    apply(r3_t3);
    apply(r3_t4_all);

    apply(ext1_t1);
    apply(ext1_t2);
    apply(ext1_t3);
    apply(ext1_t4);

    apply(ext2_t1);
    apply(ext2_t2);
    apply(ext2_t3);
    apply(ext2_t4);

    apply(ext3_t1);
    apply(ext3_t2);
    apply(ext3_t3);
    apply(ext3_t4);
}


// *********************************
//            EGRESS
// *********************************


control egress {
}

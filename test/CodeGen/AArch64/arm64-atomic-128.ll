; RUN: llc < %s -march=arm64 -mtriple=arm64-linux-gnu -verify-machineinstrs -mcpu=cyclone | FileCheck %s

@var = global i128 0

define i128 @val_compare_and_swap(i128* %p, i128 %oldval, i128 %newval) {
; CHECK-LABEL: val_compare_and_swap:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp   [[RESULTLO:x[0-9]+]], [[RESULTHI:x[0-9]+]], [x[[ADDR:[0-9]+]]]
; CHECK-DAG: eor     [[MISMATCH_LO:x[0-9]+]], [[RESULTLO]], x2
; CHECK-DAG: eor     [[MISMATCH_HI:x[0-9]+]], [[RESULTHI]], x3
; CHECK: orr [[MISMATCH:x[0-9]+]], [[MISMATCH_LO]], [[MISMATCH_HI]]
; CHECK: cbnz    [[MISMATCH]], [[DONE:.LBB[0-9]+_[0-9]+]]
; CHECK: stxp   [[SCRATCH_RES:w[0-9]+]], x4, x5, [x[[ADDR]]]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]
; CHECK: [[DONE]]:
  %val = cmpxchg i128* %p, i128 %oldval, i128 %newval acquire acquire
  ret i128 %val
}

define void @fetch_and_nand(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_nand:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldxp  [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK-DAG: bic    [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2
; CHECK-DAG: bic    [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw nand i128* %p, i128 %bits release
  store i128 %val, i128* @var, align 16
  ret void
}

define void @fetch_and_or(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_or:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp  [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK-DAG: orr    [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2
; CHECK-DAG: orr    [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw or i128* %p, i128 %bits seq_cst
  store i128 %val, i128* @var, align 16
  ret void
}

define void @fetch_and_add(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_add:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp  [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK: adds   [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2
; CHECK: adcs   [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw add i128* %p, i128 %bits seq_cst
  store i128 %val, i128* @var, align 16
  ret void
}

define void @fetch_and_sub(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_sub:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp  [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK: subs   [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2
; CHECK: sbcs    [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw sub i128* %p, i128 %bits seq_cst
  store i128 %val, i128* @var, align 16
  ret void
}

define void @fetch_and_min(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_min:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp   [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK: cmp     [[DEST_REGLO]], x2
; CHECK: cset    [[LOCMP:w[0-9]+]], ls
; CHECK: cmp     [[DEST_REGHI:x[0-9]+]], x3
; CHECK: cset    [[HICMP:w[0-9]+]], le
; CHECK: csel    [[CMP:w[0-9]+]], [[LOCMP]], [[HICMP]], eq
; CHECK: cmp     [[CMP]], #0
; CHECK-DAG: csel    [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3, ne
; CHECK-DAG: csel    [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2, ne
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw min i128* %p, i128 %bits seq_cst
  store i128 %val, i128* @var, align 16
  ret void
}

define void @fetch_and_max(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_max:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp  [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK: cmp     [[DEST_REGLO]], x2
; CHECK: cset    [[LOCMP:w[0-9]+]], hi
; CHECK: cmp     [[DEST_REGHI:x[0-9]+]], x3
; CHECK: cset    [[HICMP:w[0-9]+]], gt
; CHECK: csel    [[CMP:w[0-9]+]], [[LOCMP]], [[HICMP]], eq
; CHECK: cmp     [[CMP]], #0
; CHECK-DAG: csel    [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3, ne
; CHECK-DAG: csel    [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2, ne
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw max i128* %p, i128 %bits seq_cst
  store i128 %val, i128* @var, align 16
  ret void
}

define void @fetch_and_umin(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_umin:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp  [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK: cmp     [[DEST_REGLO]], x2
; CHECK: cset    [[LOCMP:w[0-9]+]], ls
; CHECK: cmp     [[DEST_REGHI:x[0-9]+]], x3
; CHECK: cset    [[HICMP:w[0-9]+]], ls
; CHECK: csel    [[CMP:w[0-9]+]], [[LOCMP]], [[HICMP]], eq
; CHECK: cmp     [[CMP]], #0
; CHECK-DAG: csel    [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3, ne
; CHECK-DAG: csel    [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2, ne
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw umin i128* %p, i128 %bits seq_cst
  store i128 %val, i128* @var, align 16
  ret void
}

define void @fetch_and_umax(i128* %p, i128 %bits) {
; CHECK-LABEL: fetch_and_umax:
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp  [[DEST_REGLO:x[0-9]+]], [[DEST_REGHI:x[0-9]+]], [x0]
; CHECK: cmp     [[DEST_REGLO]], x2
; CHECK: cset    [[LOCMP:w[0-9]+]], hi
; CHECK: cmp     [[DEST_REGHI:x[0-9]+]], x3
; CHECK: cset    [[HICMP:w[0-9]+]], hi
; CHECK: csel    [[CMP:w[0-9]+]], [[LOCMP]], [[HICMP]], eq
; CHECK: cmp     [[CMP]], #0
; CHECK-DAG: csel    [[SCRATCH_REGHI:x[0-9]+]], [[DEST_REGHI]], x3, ne
; CHECK-DAG: csel    [[SCRATCH_REGLO:x[0-9]+]], [[DEST_REGLO]], x2, ne
; CHECK: stlxp  [[SCRATCH_RES:w[0-9]+]], [[SCRATCH_REGLO]], [[SCRATCH_REGHI]], [x0]
; CHECK: cbnz   [[SCRATCH_RES]], [[LABEL]]

; CHECK-DAG: str    [[DEST_REGHI]]
; CHECK-DAG: str    [[DEST_REGLO]]
  %val = atomicrmw umax i128* %p, i128 %bits seq_cst
  store i128 %val, i128* @var, align 16
  ret void
}

define i128 @atomic_load_seq_cst(i128* %p) {
; CHECK-LABEL: atomic_load_seq_cst:
; CHECK-NOT: dmb
; CHECK-LABEL: ldaxp
; CHECK-NOT: dmb
   %r = load atomic i128* %p seq_cst, align 16
   ret i128 %r
}

define i128 @atomic_load_relaxed(i128* %p) {
; CHECK-LABEL: atomic_load_relaxed:
; CHECK-NOT: dmb
; CHECK: ldxp [[LO:x[0-9]+]], [[HI:x[0-9]+]], [x0]
; CHECK-NOT: dmb
   %r = load atomic i128* %p monotonic, align 16
   ret i128 %r
}


define void @atomic_store_seq_cst(i128 %in, i128* %p) {
; CHECK-LABEL: atomic_store_seq_cst:
; CHECK-NOT: dmb
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldaxp xzr, xzr, [x2]
; CHECK: stlxp [[SUCCESS:w[0-9]+]], x0, x1, [x2]
; CHECK: cbnz [[SUCCESS]], [[LABEL]]
; CHECK-NOT: dmb
   store atomic i128 %in, i128* %p seq_cst, align 16
   ret void
}

define void @atomic_store_release(i128 %in, i128* %p) {
; CHECK-LABEL: atomic_store_release:
; CHECK-NOT: dmb
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldxp xzr, xzr, [x2]
; CHECK: stlxp [[SUCCESS:w[0-9]+]], x0, x1, [x2]
; CHECK: cbnz [[SUCCESS]], [[LABEL]]
; CHECK-NOT: dmb
   store atomic i128 %in, i128* %p release, align 16
   ret void
}

define void @atomic_store_relaxed(i128 %in, i128* %p) {
; CHECK-LABEL: atomic_store_relaxed:
; CHECK-NOT: dmb
; CHECK: [[LABEL:.?LBB[0-9]+_[0-9]+]]:
; CHECK: ldxp xzr, xzr, [x2]
; CHECK: stxp [[SUCCESS:w[0-9]+]], x0, x1, [x2]
; CHECK: cbnz [[SUCCESS]], [[LABEL]]
; CHECK-NOT: dmb
   store atomic i128 %in, i128* %p unordered, align 16
   ret void
}

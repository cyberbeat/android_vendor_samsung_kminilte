#!/bin/sh
# Re-apply binary patch to proprietary hwcomposer.exynos3.so after blob
# re-extraction (extract-files.sh), or to a build-time copy in out/.
# Idempotent.
#
# Usage: patch_hwc_query.sh [target.so]
#   default target: the repo blob (manual re-patch after re-extraction)
#
# Fix: exynos5_query() claimed HWC_BACKGROUND_LAYER_SUPPORTED=1, but
# libdisplay.so dereferences layer->handle unconditionally (private_handle_t
# magic check at libdisplay.so+0x2df0, crash at +0x2df6). Android 10's
# HWC2On1Adapter then places the SolidColor value in the handle union slot
# -> SF crash (SIGSEGV on 0xff000000).
#
# Patch: query() "what==0" path:  movs r0,#1  ->  movs r0,#0
#   file offset 0x19a2:  byte 0x01 -> 0x00   (Thumb instr 0x2001 -> 0x2000)
# Result: *value=0, return 0 -> adapter marks background unsupported ->
# writes handle=nullptr -> blob skips layer safely; color is composed into
# the GLES FB target instead. All other query/overlay paths untouched.
#
# Verify after patch: md5sum must be 3be05961e4634978f3b9a2f81bef3116
# Original blob md5:      5f0a7c1c14a84d8914f9be1f3b756115

BLOB="${1:-$(dirname "$0")/../proprietary/lib/hw/hwcomposer.exynos3.so}"

byte="$(od -An -tx1 -j 6562 -N1 "$BLOB" | tr -d ' ')"   # 0x19a2
case "$byte" in
  00) echo "already patched (movs r0,#0)"; exit 0 ;;
  01) printf '\x00' | dd of="$BLOB" bs=1 seek=6562 count=1 conv=notrunc 2>/dev/null
      echo "patched: query() now returns supported=0 for HWC_BACKGROUND" ;;
  *)  echo "UNEXPECTED byte $byte at 0x19a2 -- blob changed? aborting" >&2
      exit 1 ;;
esac

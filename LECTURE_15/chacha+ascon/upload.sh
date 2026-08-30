#!/bin/bash
# SD upload for the ASCON SP 800-232 demo (Arty 100T, SmallRocket32AsconArty100TConfig).
#
# The sdboot bootrom reads the payload from ABSOLUTE sector 2048
# (BBL_PARTITION_START_SECTOR in fpga/src/main/resources/arty35t/sdboot/sd.c),
# which is where partition 1 starts on a 1 MiB-aligned card. So the binary goes
# to the PARTITION device at offset 0, not to the whole disk.
#
# Usage: sudo ./upload.sh [device]
#   device: sdc1, sdb1, mmcblk0p1, ...   (default sdc1)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE=${1:-sdc1}
DEVICE_PATH="/dev/$DEVICE"
BINARY="$SCRIPT_DIR/build/main.bin"

if [ ! -f "$BINARY" ]; then
    echo "$BINARY missing — building..."
    make -C "$SCRIPT_DIR" bin
fi

if [ ! -b "$DEVICE_PATH" ]; then
    echo "Error: block device $DEVICE_PATH not found."
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "sd[a-z][0-9]|mmcblk[0-9]p[0-9]" || true
    exit 1
fi

# The bootrom seeks to a hardcoded absolute sector. If partition 1 does not
# start exactly there the board silently boots garbage, so check rather than
# assume -- this is the one failure mode that produces no error message.
PART_START=$(cat "/sys/class/block/$DEVICE/start" 2>/dev/null || echo "unknown")
if [ "$PART_START" != "2048" ]; then
    echo "WARNING: $DEVICE_PATH starts at sector $PART_START, but the bootrom"
    echo "         reads absolute sector 2048. The board will not boot this image."
    echo "         Repartition with 1 MiB alignment, or write the sector directly:"
    echo "           sudo dd if=$BINARY of=/dev/${DEVICE%%[0-9]*} bs=512 seek=2048 conv=fsync"
    echo ""
fi

if mount | grep -q "^$DEVICE_PATH "; then
    echo "Error: $DEVICE_PATH is mounted. Unmount it first:  sudo umount $DEVICE_PATH"
    exit 1
fi

echo "=========================================="
echo "  ASCON demo -> SD"
echo "=========================================="
echo "Binary: $BINARY  ($(stat -c%s "$BINARY") bytes)"
echo "Device: $DEVICE_PATH  (partition starts at sector $PART_START)"
echo ""
read -p "Continue with upload? [Y/n] " -n 1 -r; echo
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo "Cancelled."; exit 0
fi

echo "Writing..."
# Whole-disk node: sdc1 -> /dev/sdc, mmcblk0p1 -> /dev/mmcblk0
case "$DEVICE" in
    mmcblk*) DISK_PATH="/dev/${DEVICE%p[0-9]*}" ;;
    *)       DISK_PATH="/dev/${DEVICE%%[0-9]*}" ;;
esac

# The bootrom issues CMD18 with argument 2048 and never inspects the CCS bit
# returned by CMD58 (sd.c: sd_cmd58() reads the OCR and discards it), so the
# meaning of that argument depends on the card:
#
#   SDHC/SDXC (CCS=1): block index  -> sector 2048
#   SDSC      (CCS=0): byte address -> byte 2048 = sector 4
#
# Writing both costs nothing and boots on either card. Sector 4 lies in the MBR
# gap (sectors 1..2047), unused on a standard layout, so it clobbers neither the
# partition table (sector 0) nor partition 1.
NSEC=$(( ($(stat -c%s "$BINARY") + 511) / 512 ))
dd if="$BINARY" of="$DISK_PATH" bs=512 seek=4    conv=fsync status=none
dd if="$BINARY" of="$DISK_PATH" bs=512 seek=2048 conv=fsync status=none
sync

# A silent no-op write (empty reader, stale device node) looks identical to
# success at the UART, so read both locations back and compare.
SZ=$(stat -c%s "$BINARY")
ok=0
for sec in 4 2048; do
    if dd if="$DISK_PATH" bs=512 skip=$sec count=$NSEC 2>/dev/null \
         | cmp -s -n "$SZ" - "$BINARY"; then
        echo "  verified at sector $sec"
        ok=1
    else
        echo "  MISMATCH at sector $sec"
    fi
done
[ "$ok" = "1" ] || { echo "ERROR: neither location verified - do not expect a boot."; exit 1; }

echo ""
echo "Done. Insert SD, reset the board, watch UART0 for 'RESULT: ALL PASS'."

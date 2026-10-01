# odroid-firstboot

Performs first-boot root partition/filesystem expansion, optional swap partition
creation, and SSH host-key setup. The systemd service records successful
completion in `/var/lib/odroid-firstboot.done`.

## Root filesystem expansion

After updating the partition table and refreshing the kernel's partition view,
the script detects the mounted `/` filesystem with `findmnt`:

- EXT2/EXT3/EXT4: `resize2fs "$ROOTPART"`
- BTRFS: `btrfs filesystem resize max /`

BTRFS must be mounted read-write. It uses the mounted root path, not a device
argument. This supports the single-device BTRFS rootfs produced by odroid-stamper.
The package depends on `btrfs-progs` for the BTRFS operation.

Partition-table, kernel-refresh, and filesystem-resize errors stop the entry
point with a nonzero status so the service does not create its success marker.
Existing completion markers are not removed by this change.

For a system whose partition has already grown, expand BTRFS directly on the
running ODROID without repeating first-boot partitioning or SSH setup:

```bash
sudo btrfs filesystem resize max /
sudo btrfs filesystem usage /
```

## Tests

```bash
bash tests/resize-rootfs.sh
```

The test mocks external commands; it does not modify a block device. It checks
EXT/BTRFS command dispatch, unsupported filesystems, command failures, partition
refresh failures, and the entry point's failure status. Actual first-boot resize
still needs verification on target hardware.

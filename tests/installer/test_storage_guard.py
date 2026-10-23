"""
Unit tests for AstraOS Storage Safety Guard and Planner.
"""

import unittest
from astra_installer.models import OperationType, SwapMode
from astra_installer.storage_guard import (
    DiskMeta,
    PartitionMeta,
    build_erase_plan,
    MIN_STORAGE_BYTES,
)


class TestStorageGuard(unittest.TestCase):
    def test_storage_floor_enforcement(self):
        # Disk smaller than 35 GiB must be rejected
        small_disk = DiskMeta(
            node="/dev/sda",
            name="sda",
            model="Small Disk",
            size_bytes=20 * (1024**3),  # 20 GiB
            pttype="gpt",
            serial="123",
            wwn="456",
            removable=False,
            is_live=False,
            partitions=[]
        )
        plan = build_erase_plan(small_disk, SwapMode.ZRAM, 4)
        self.assertFalse(plan.valid)
        self.assertIn("smaller than the required 35 GiB floor", plan.validation_error)

    def test_valid_disk_erase_plan(self):
        valid_disk = DiskMeta(
            node="/dev/sda",
            name="sda",
            model="QEMU HARDDISK",
            size_bytes=40 * (1024**3),  # 40 GiB
            pttype="gpt",
            serial="ABC",
            wwn="DEF",
            removable=False,
            is_live=False,
            partitions=[]
        )
        plan = build_erase_plan(valid_disk, SwapMode.ZRAM, 4)
        self.assertTrue(plan.valid)
        self.assertEqual(plan.esp_device, "/dev/sda1")
        self.assertEqual(plan.root_device, "/dev/sda2")

        # Operations must contain WIPE, CREATE ESP, FORMAT ESP, CREATE ROOT, FORMAT ROOT
        op_types = [op.op_type for op in plan.operations]
        self.assertIn(OperationType.WIPE_DISK, op_types)
        self.assertIn(OperationType.CREATE_PARTITION, op_types)
        self.assertIn(OperationType.FORMAT, op_types)

    def test_swap_partition_included_when_selected(self):
        disk = DiskMeta(
            node="/dev/nvme0n1",
            name="nvme0n1",
            model="NVMe Drive",
            size_bytes=50 * (1024**3),
            pttype="gpt",
            serial="SN123",
            wwn="W1",
            removable=False,
            is_live=False,
            partitions=[]
        )
        plan = build_erase_plan(disk, SwapMode.PARTITION, 8)
        self.assertTrue(plan.valid)
        self.assertIsNotNone(plan.swap_device)
        self.assertEqual(plan.swap_device, "/dev/nvme0n1p2")
        self.assertEqual(plan.root_device, "/dev/nvme0n1p3")


if __name__ == "__main__":
    unittest.main()

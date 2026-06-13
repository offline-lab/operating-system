"""General system health — boot state, systemd, mounts, not package-specific."""

import pytest


def test_hostname(host):
    assert host.check_output("hostname") == "offlinelab"


def test_no_failed_units(host):
    result = host.run("systemctl list-units --state=failed --no-legend")
    assert result.rc == 0
    # psplash is expected to fail in QEMU (no framebuffer in -nographic mode)
    failed = [
        line for line in result.stdout.splitlines()
        if line.strip() and "psplash" not in line
    ]
    assert failed == [], f"Failed units:\n" + "\n".join(failed)


def test_multi_user_target_reached(host):
    assert host.run("systemctl is-active multi-user.target").rc == 0


def test_rauc_slot_in_cmdline(host):
    cmdline = host.file("/proc/cmdline").content_string
    assert "rauc.slot=" in cmdline, f"rauc.slot not in cmdline: {cmdline}"


def test_machine_id_initialized(host):
    machine_id = host.file("/etc/machine-id").content_string.strip()
    assert machine_id != "uninitialized", "machine-id not set after first boot"
    assert len(machine_id) == 32, f"machine-id wrong length: '{machine_id}'"


def test_bin_is_merged_usr_symlink(host):
    assert host.file("/bin").is_symlink, "/bin is not a symlink (merged-usr broken)"


def test_systemd_networkd_running(host):
    assert host.service("systemd-networkd").is_running


@pytest.mark.skip(reason="systemd-resolved is disabled on this image")
def test_systemd_resolved_running(host):
    assert host.service("systemd-resolved").is_running


def test_data_partition_mounted(host):
    mount = host.mount_point("/data")
    assert mount.exists, "/data not mounted"
    assert mount.filesystem == "ext4", f"/data filesystem: {mount.filesystem}"


def test_tmp_is_tmpfs(host):
    mount = host.mount_point("/tmp")
    assert mount.exists, "/tmp not mounted"
    assert mount.filesystem == "tmpfs", f"/tmp filesystem: {mount.filesystem}"


def test_overlay_mounted(host):
    result = host.run("mount")
    assert "overlay" in result.stdout, "overlayfs not mounted (rootfs is read-write?)"


def test_kernel_version_present(host):
    uname = host.check_output("uname -r")
    assert len(uname) > 5, f"Unexpected kernel version: '{uname}'"


def test_dmesg_no_kernel_panic(sudo_host):
    result = sudo_host.run("dmesg")
    assert "Kernel panic" not in result.stdout, "Kernel panic in dmesg"
    assert "BUG:" not in result.stdout, "Kernel BUG in dmesg"

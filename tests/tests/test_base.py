"""offlinelab-base package: users, groups, mounts, services, scripts, framework."""


# ---------------------------------------------------------------------------
# Users and groups (created via users.txt — present in all builds)
# ---------------------------------------------------------------------------

def test_admin_user_exists(host):
    user = host.user("admin")
    assert user.exists
    assert user.uid == 1000
    assert user.group == "admin"
    assert user.shell == "/bin/bash"
    assert user.home == "/home/admin"


def test_admin_in_sudo_group(host):
    assert "admin" in host.group("sudo").members


def test_required_groups_exist(host):
    for grp in ("sudo", "wheel", "audio", "video", "bluetooth", "netdev", "systemd-journal", "disco"):
        assert host.group(grp).exists, f"Group missing: {grp}"


def test_root_is_locked(sudo_host):
    passwd = sudo_host.file("/etc/shadow").content_string
    root_entry = next((l for l in passwd.splitlines() if l.startswith("root:")), None)
    assert root_entry is not None, "root not in /etc/shadow"
    pw_field = root_entry.split(":")[1]
    assert pw_field in ("!", "*", "!*"), f"root password not locked: {pw_field}"


# ---------------------------------------------------------------------------
# Filesystem layout
# ---------------------------------------------------------------------------

def test_data_mountpoint_exists(host):
    assert host.file("/data").is_directory


def test_boot_firmware_mountpoint_exists(host):
    assert host.file("/boot/firmware").is_directory


def test_var_lib_extensions_is_directory(host):
    f = host.file("/var/lib/extensions")
    assert f.is_directory and not f.is_symlink


def test_etc_extensions_is_directory(host):
    f = host.file("/etc/extensions")
    assert f.is_directory and not f.is_symlink


# ---------------------------------------------------------------------------
# System configuration files
# ---------------------------------------------------------------------------

def test_etc_issue_has_branding(host):
    assert "Offline Lab OS" in host.file("/etc/issue").content_string


def test_etc_issue_net_has_branding(host):
    assert "Offline Lab OS" in host.file("/etc/issue.net").content_string


def test_etc_hostname(host):
    assert host.file("/etc/hostname").content_string.strip() == "offlinelab"


def test_etc_fstab_has_no_mounts(host):
    # All mounts are managed by systemd unit files; fstab intentionally has no entries
    lines = [
        line for line in host.file("/etc/fstab").content_string.splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    assert lines == [], f"/etc/fstab should have no mount entries (uses systemd units): {lines}"


def test_sysctl_config_present(host):
    assert host.file("/etc/sysctl.d/99-offlinelab.conf").exists


def test_zram_default_config_present(host):
    assert host.file("/etc/default/zram-swap").exists


def test_tmpfiles_offlinelab_base(host):
    assert host.file("/etc/tmpfiles.d/offlinelab-base.conf").exists


# ---------------------------------------------------------------------------
# Sudoers
# ---------------------------------------------------------------------------

def test_sudoers_defaults_conf(host):
    assert host.file("/etc/sudoers.d/defaults.conf").exists


def test_sudoers_sudo_group_conf(sudo_host):
    f = sudo_host.file("/etc/sudoers.d/sudo-group.conf")
    assert f.exists
    assert "%sudo" in f.content_string


def test_sudoers_include_conf(host):
    assert host.file("/etc/sudoers.d/include.conf").exists


# ---------------------------------------------------------------------------
# Systemd mount units
# ---------------------------------------------------------------------------

def test_boot_firmware_mount_unit_exists(host):
    assert host.file("/etc/systemd/system/boot-firmware.mount").exists


def test_boot_firmware_mount_has_bootfs_label(host):
    content = host.file("/etc/systemd/system/boot-firmware.mount").content_string
    assert "LABEL=bootfs" in content or "bootfs" in content


def test_boot_firmware_mount_enabled(host):
    assert host.file(
        "/etc/systemd/system/local-fs.target.wants/boot-firmware.mount"
    ).is_symlink


def test_var_lib_extensions_mount_enabled(host):
    assert host.file(
        "/etc/systemd/system/sysinit.target.wants/var-lib-extensions.mount"
    ).is_symlink


def test_etc_extensions_mount_enabled(host):
    assert host.file(
        "/etc/systemd/system/sysinit.target.wants/etc-extensions.mount"
    ).is_symlink


def test_systemd_sysext_enabled(host):
    assert host.file(
        "/etc/systemd/system/sysinit.target.wants/systemd-sysext.service"
    ).is_symlink


def test_systemd_confext_enabled(host):
    assert host.file(
        "/etc/systemd/system/sysinit.target.wants/systemd-confext.service"
    ).is_symlink


# ---------------------------------------------------------------------------
# Systemd service units
# ---------------------------------------------------------------------------

def test_repart_drop_in_installed(host):
    assert host.file("/usr/lib/repart.d/10-data.conf").exists


def test_repart_drop_in_targets_data_label(host):
    content = host.file("/usr/lib/repart.d/10-data.conf").content_string
    assert "Label=data" in content


def test_repart_drop_in_grows_filesystem(host):
    content = host.file("/usr/lib/repart.d/10-data.conf").content_string
    assert "GrowFileSystem=yes" in content


def test_systemd_repart_binary_present(host):
    assert host.file("/usr/bin/systemd-repart").exists


def test_power_profile_enabled(host):
    assert host.service("power-profile").is_enabled


def test_psplash_quit_enabled(host):
    assert host.service("psplash-quit").is_enabled


def test_getty_ttyS0_enabled(host):
    assert host.file(
        "/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"
    ).is_symlink


def test_getty_tty1_enabled(host):
    assert host.file(
        "/etc/systemd/system/getty.target.wants/getty@tty1.service"
    ).is_symlink


# ---------------------------------------------------------------------------
# Framework and tooling
# ---------------------------------------------------------------------------

def test_framework_binary_present(host):
    assert host.file("/usr/lib/framework/bin/framework").exists


def test_boxctl_binary_present(host):
    assert host.file("/usr/lib/framework/bin/boxctl").exists


def test_framework_sourceable(host):
    result = host.run("bash -c 'source /usr/lib/framework/bin/framework && echo OK'")
    assert result.rc == 0, f"Framework failed to source: {result.stderr}"
    assert "OK" in result.stdout


def test_profile_d_framework_present(host):
    assert host.file("/etc/profile.d/framework.sh").exists


# ---------------------------------------------------------------------------
# Networking config
# ---------------------------------------------------------------------------

def test_usb0_network_config(host):
    cfg = host.file("/etc/systemd/network/usb0.network").content_string
    assert "DHCPServer" in cfg
    assert "10.55.0.1" in cfg


def test_wlan0_network_config_exists(host):
    assert host.file("/etc/systemd/network/wlan0.network").exists


# ---------------------------------------------------------------------------
# Data partition writability (runtime)
# ---------------------------------------------------------------------------

def test_data_is_writable(sudo_host):
    result = sudo_host.run("touch /data/.write-test && rm /data/.write-test")
    assert result.rc == 0, f"Cannot write to /data: {result.stderr}"


# ---------------------------------------------------------------------------
# Clock and machine-id persistence services
# ---------------------------------------------------------------------------

def test_clock_load_service_exists(host):
    assert host.file("/etc/systemd/system/clock-load.service").exists


def test_clock_load_service_enabled(host):
    assert host.service("clock-load").is_enabled


def test_clock_save_service_exists(host):
    assert host.file("/etc/systemd/system/clock-save.service").exists


def test_clock_save_service_enabled(host):
    assert host.service("clock-save").is_enabled


def test_persist_machine_id_service_exists(host):
    assert host.file("/etc/systemd/system/persist-machine-id.service").exists


def test_persist_machine_id_service_enabled(host):
    assert host.service("persist-machine-id").is_enabled

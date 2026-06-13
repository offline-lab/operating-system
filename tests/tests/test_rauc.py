"""offlinelab-rauc: A/B slot state, fw_env, mark-good, USB OTA handler."""


def test_rauc_binary_present(host):
    assert host.file("/usr/bin/rauc").exists


def test_rauc_version(host):
    result = host.run("rauc --version")
    assert result.rc == 0, f"rauc --version failed: {result.stderr}"


def test_fw_printenv_present(sudo_host):
    assert sudo_host.file("/usr/sbin/fw_printenv").exists


def test_fw_env_config_present(host):
    assert host.file("/etc/fw_env.config").exists


def test_fw_env_config_has_bootstate_partition(sudo_host):
    content = sudo_host.file("/etc/fw_env.config").content_string
    # Should reference /dev/vda6 (qemu) or /dev/mmcblk0p6 (pi) — GPT p6=bootstate
    assert "p6" in content or "vda6" in content, (
        f"fw_env.config does not reference bootstate partition:\n{content}"
    )


def test_rauc_system_conf_present(host):
    assert host.file("/etc/rauc/system.conf").exists


def test_rauc_system_conf_uses_uboot(host):
    content = host.file("/etc/rauc/system.conf").content_string
    assert "bootloader=uboot" in content


def test_rauc_keyring_present(host):
    assert host.file("/etc/rauc/keyring.pem").exists


def test_boot_order_set(sudo_host):
    result = sudo_host.run("fw_printenv BOOT_ORDER")
    assert result.rc == 0, f"fw_printenv BOOT_ORDER failed: {result.stderr}"
    assert "A" in result.stdout or "B" in result.stdout, (
        f"BOOT_ORDER unexpected: {result.stdout}"
    )


def test_initial_slot_is_a(host):
    cmdline = host.file("/proc/cmdline").content_string
    assert "rauc.slot=A" in cmdline, (
        f"Expected rauc.slot=A in cmdline (fresh image), got: {cmdline}"
    )


def test_rauc_status(sudo_host):
    result = sudo_host.run("rauc status")
    assert result.rc == 0, f"rauc status failed:\n{result.stderr}"


def test_slot_a_marked_good(sudo_host):
    result = sudo_host.run("rauc status")
    assert result.rc == 0
    assert "good" in result.stdout.lower(), (
        f"Slot A not marked good (rauc-mark-good may not have run yet):\n{result.stdout}"
    )


def test_rauc_mark_good_enabled(host):
    assert host.service("rauc-mark-good").is_enabled


def test_usb_update_handler_present(host):
    assert host.file("/usr/local/bin/init-usb-update").exists


def test_usb_update_service_template_present(host):
    assert host.file("/etc/systemd/system/usb-update@.service").exists


def test_usb_update_udev_rule_present(host):
    assert host.file(
        "/usr/lib/udev/rules.d/99-offlinelab-usb-update.rules"
    ).exists

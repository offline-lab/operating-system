"""offlinelab-wifi: WiFi setup, show-ip, network config, udev rules."""


def test_wifi_setup_service_exists(host):
    assert host.file("/etc/systemd/system/wifi-setup.service").exists


def test_wifi_setup_service_enabled(host):
    assert host.service("wifi-setup").is_enabled


def test_init_wifi_setup_executable(host):
    f = host.file("/usr/local/bin/init-wifi-setup")
    assert f.exists
    assert f.mode & 0o111, "/usr/local/bin/init-wifi-setup not executable"


def test_show_ip_service_exists(host):
    assert host.file("/etc/systemd/system/show-ip.service").exists


def test_show_ip_service_enabled(host):
    assert host.service("show-ip").is_enabled


def test_init_show_ip_executable(host):
    f = host.file("/usr/local/bin/init-show-ip")
    assert f.exists
    assert f.mode & 0o111, "/usr/local/bin/init-show-ip not executable"


def test_wlan0_network_config_exists(host):
    assert host.file("/etc/systemd/network/wlan0.network").exists


def test_wifi_modprobe_fix_exists(host):
    assert host.file("/etc/modprobe.d/02w-wifi-fix.conf").exists


def test_wifi_power_save_udev_rule(host):
    assert host.file("/etc/udev/rules.d/80-wifi-power-save.rules").exists

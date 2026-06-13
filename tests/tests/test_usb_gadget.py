"""offlinelab-usb-gadget: USB gadget service, serial getty, network config, modules."""


def test_usb_gadget_service_exists(host):
    assert host.file("/etc/systemd/system/usb-gadget.service").exists


def test_usb_gadget_service_enabled_at_sysinit(host):
    assert host.file(
        "/etc/systemd/system/sysinit.target.wants/usb-gadget.service"
    ).is_symlink


def test_init_usb_gadget_executable(host):
    f = host.file("/usr/local/bin/init-usb-gadget")
    assert f.exists
    assert f.mode & 0o111, "/usr/local/bin/init-usb-gadget not executable"


def test_usb_gadget_modules_load_exists(host):
    assert host.file("/etc/modules-load.d/99-offlinelab-usb-gadget.conf").exists


def test_usb_gadget_modules_load_has_dwc2(host):
    content = host.file("/etc/modules-load.d/99-offlinelab-usb-gadget.conf").content_string
    assert "dwc2" in content


def test_usb_gadget_modules_load_has_configfs(host):
    content = host.file("/etc/modules-load.d/99-offlinelab-usb-gadget.conf").content_string
    assert "configfs" in content


def test_serial_getty_ttyGS0_enabled(host):
    assert host.file(
        "/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service"
    ).is_symlink


def test_wait_for_gadget_override_exists(host):
    assert host.file(
        "/etc/systemd/system/serial-getty@ttyGS0.service.d/wait-for-gadget.conf"
    ).exists


def test_usb0_network_config_exists(host):
    assert host.file("/etc/systemd/network/usb0.network").exists


def test_usb0_has_dhcp_server(host):
    assert "DHCPServer" in host.file("/etc/systemd/network/usb0.network").content_string


def test_usb0_has_correct_address(host):
    assert "10.55.0.1" in host.file("/etc/systemd/network/usb0.network").content_string

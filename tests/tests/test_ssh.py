"""offlinelab-ssh: Dropbear SSH server."""


def test_dropbear_binary_present(host):
    assert host.file("/usr/sbin/dropbear").exists


def test_dropbear_service_exists(host):
    assert host.file("/etc/systemd/system/dropbear.service").exists


def test_dropbear_service_enabled(host):
    assert host.service("dropbear").is_enabled


def test_dropbear_wants_bootconf(host):
    content = host.file("/etc/systemd/system/dropbear.service").content_string
    assert "Wants=bootconf.service" in content, (
        "dropbear.service must soft-depend on bootconf.service (Wants, not Requires)"
    )


def test_dropbear_condition_on_ssh_config(host):
    content = host.file("/etc/systemd/system/dropbear.service").content_string
    assert "ConditionPathExists" in content
    assert "/data/config/services/ssh" in content


def test_dropbear_uses_data_hostkey(host):
    content = host.file("/etc/systemd/system/dropbear.service").content_string
    assert "/data/config/ssh/hostkey" in content


def test_dropbear_uses_issue_net_banner(host):
    content = host.file("/etc/systemd/system/dropbear.service").content_string
    assert "/etc/issue.net" in content


def test_dropbear_running(host):
    assert host.service("dropbear").is_running


def test_ssh_port_listening(host):
    result = host.run("ss -tlnp")
    assert ":22" in result.stdout, "SSH port 22 not listening"


def test_data_config_ssh_exists(host):
    # Dropbear only starts if this file exists; since we're SSHed in, it must
    assert host.file("/data/config/services/ssh").exists


def test_ssh_hostkey_generated(host):
    """bootconf generates the SSH host key at /data/config/ssh/hostkey on first boot."""
    f = host.file("/data/config/ssh/hostkey")
    assert f.exists
    assert f.size > 0, "/data/config/ssh/hostkey exists but is empty"

"""offlinelab-disco: service daemon, NSS module, CLI, user account."""


def test_disco_daemon_binary_present(host):
    assert host.file("/usr/bin/disco-daemon").exists


def test_disco_cli_binary_present(host):
    assert host.file("/usr/bin/disco").exists


def test_disco_gps_broadcaster_present(host):
    assert host.file("/usr/bin/disco-gps-broadcaster").exists


def test_libnss_disco_installed(host):
    assert host.file("/usr/lib/libnss_disco.so.2").exists


def test_nsswitch_has_disco(host):
    nsswitch = host.file("/etc/nsswitch.conf").content_string
    assert "disco" in nsswitch, "disco not in nsswitch.conf"


def test_disco_config_present(host):
    assert host.file("/etc/disco/config.yaml").exists


def test_disco_user_exists(host):
    user = host.user("disco")
    assert user.exists
    assert user.uid == 800
    assert user.home == "/nonexistent"


def test_disco_user_in_passwd(host):
    assert "disco" in host.file("/etc/passwd").content_string


def test_disco_daemon_service_exists(host):
    assert host.file("/etc/systemd/system/disco-daemon.service").exists


def test_disco_daemon_enabled(host):
    assert host.service("disco-daemon").is_enabled


def test_disco_daemon_running(host):
    assert host.service("disco-daemon").is_running


def test_disco_daemon_runs_as_disco_user(host):
    result = host.run("ps -o user= -C disco-daemon")
    assert result.rc == 0, "disco-daemon not running"
    assert result.stdout.strip() == "disco", f"disco-daemon user: {result.stdout.strip()}"


def test_disco_daemon_has_cap_net_raw(sudo_host):
    result = sudo_host.run(
        "systemctl show disco-daemon -p AmbientCapabilities,CapabilityBoundingSet"
    )
    assert "cap_net_raw" in result.stdout.lower(), (
        f"CAP_NET_RAW not in disco-daemon capabilities:\n{result.stdout}"
    )


def test_disco_daemon_has_cap_sys_time(sudo_host):
    result = sudo_host.run(
        "systemctl show disco-daemon -p AmbientCapabilities,CapabilityBoundingSet"
    )
    assert "cap_sys_time" in result.stdout.lower(), (
        f"CAP_SYS_TIME not in disco-daemon capabilities:\n{result.stdout}"
    )

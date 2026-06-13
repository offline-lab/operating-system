"""offlinelab-bootconf: boot-time configuration manager."""


def test_bootconf_binary_present(host):
    f = host.file("/usr/local/bin/bootconf")
    assert f.exists


def test_bootconf_executable(host):
    f = host.file("/usr/local/bin/bootconf")
    assert f.mode & 0o111, "/usr/local/bin/bootconf not executable"


def test_bootconf_service_exists(host):
    assert host.file("/etc/systemd/system/bootconf.service").exists


def test_bootconf_service_enabled(host):
    assert host.service("bootconf").is_enabled


def test_bootconf_sysusers_service_exists(host):
    assert host.file("/etc/systemd/system/offlinelab-sysusers.service").exists


def test_bootconf_sysusers_service_enabled(host):
    assert host.service("offlinelab-sysusers").is_enabled


def test_bootconf_sysusers_uses_glob_not_directory(host):
    content = host.file("/etc/systemd/system/offlinelab-sysusers.service").content_string
    assert "/bin/sh -c" in content, "ExecStart must use /bin/sh -c for glob expansion"
    assert "*.conf" in content, "ExecStart must glob *.conf, not pass a bare directory"


def test_bootconf_sysusers_condition_is_directory(host):
    content = host.file("/etc/systemd/system/offlinelab-sysusers.service").content_string
    assert "ConditionPathIsDirectory" in content


def test_bootconf_orders_before_network(host):
    content = host.file("/etc/systemd/system/bootconf.service").content_string
    assert "Before=" in content and "network.target" in content


def test_bootconf_wants_boot_firmware_mount(host):
    content = host.file("/etc/systemd/system/bootconf.service").content_string
    assert "boot-firmware.mount" in content


def test_bootconf_condition_on_yaml(host):
    content = host.file("/etc/systemd/system/bootconf.service").content_string
    assert "ConditionPathExists" in content and "bootconf.yaml" in content


# Runtime checks — verify bootconf actually ran at boot


def test_bootconf_service_ran(host):
    """bootconf.service must have completed successfully."""
    svc = host.service("bootconf")
    assert svc.is_enabled
    result = host.run("systemctl is-active bootconf.service")
    assert result.stdout.strip() in ("active", "inactive"), (
        f"bootconf.service unexpected state: {result.stdout.strip()}"
    )
    result = host.run("systemctl show -p Result --value bootconf.service")
    assert result.stdout.strip() == "success", (
        f"bootconf.service did not succeed: {result.stdout.strip()}"
    )


def test_bootconf_wrote_status_dir(host):
    """bootconf writes a status directory to /data/config/bootconf/ when it runs."""
    assert host.file("/data/config/bootconf").is_directory


def test_systemd_sysusers_binary_present(host):
    """systemd-sysusers must be installed for offlinelab-sysusers.service to work."""
    assert host.file("/usr/bin/systemd-sysusers").exists


def test_bootconf_sysusers_service_ran(host):
    """offlinelab-sysusers.service must have completed successfully."""
    result = host.run("systemctl show -p Result --value offlinelab-sysusers.service")
    assert result.stdout.strip() == "success", (
        f"offlinelab-sysusers.service did not succeed: {result.stdout.strip()}"
    )


def test_bootconf_sysusers_conf_written(host):
    """bootconf must have written at least one .conf file into /data/config/users/."""
    result = host.run("ls /data/config/users/*.conf")
    assert result.rc == 0, "No .conf files found in /data/config/users/ — bootconf did not run sysusers"


def test_bootconf_provisioned_app_user_exists(host):
    """bootconf.yaml provisions an 'app' user; offlinelab-sysusers.service must have created it."""
    user = host.user("app")
    assert user.exists, "app user not found — offlinelab-sysusers.service may have failed"


def test_bootconf_provisioned_app_user_shell(host):
    user = host.user("app")
    assert user.shell in ("/bin/bash", "/bin/sh"), f"app user has unexpected shell: {user.shell}"


def test_bootconf_provisioned_app_user_home(host):
    user = host.user("app")
    assert user.home == "/data/home/app"

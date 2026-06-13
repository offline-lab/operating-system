"""offlinelab-portable: portablectl, sysext/confext, AppArmor, squashfs."""


def test_portablectl_present(host):
    assert host.file("/usr/bin/portablectl").exists


def test_systemd_sysext_present(host):
    assert host.file("/usr/bin/systemd-sysext").exists


def test_systemd_confext_present(host):
    assert host.file("/usr/bin/systemd-confext").exists


def test_portables_symlink_to_data_apps(host):
    f = host.file("/var/lib/portables")
    assert f.is_symlink, "/var/lib/portables is not a symlink"
    assert f.linked_to == "/data/apps", (
        f"/var/lib/portables -> {f.linked_to}, expected /data/apps"
    )


def test_var_lib_extensions_is_plain_directory(host):
    f = host.file("/var/lib/extensions")
    assert f.is_directory, "/var/lib/extensions missing"
    assert not f.is_symlink, "/var/lib/extensions should not be a symlink"


def test_etc_extensions_is_plain_directory(host):
    f = host.file("/etc/extensions")
    assert f.is_directory, "/etc/extensions missing"
    assert not f.is_symlink, "/etc/extensions should not be a symlink"


def test_sysext_service_enabled(host):
    assert host.service("systemd-sysext").is_enabled


def test_confext_service_enabled(host):
    assert host.service("systemd-confext").is_enabled


def test_default_portable_profile_present(host):
    assert host.file("/etc/portables/default.conf").exists


def test_default_profile_has_protect_system(host):
    content = host.file("/etc/portables/default.conf").content_string
    assert "ProtectSystem=strict" in content


def test_default_profile_has_no_new_privileges(host):
    content = host.file("/etc/portables/default.conf").content_string
    assert "NoNewPrivileges=yes" in content


def test_squashfs_available(sudo_host):
    # squashfs may be built-in or as a module; check both
    modules_txt = sudo_host.run("grep squashfs /proc/modules 2>/dev/null || true")
    builtin = sudo_host.run(
        "grep squashfs /lib/modules/$(uname -r)/modules.builtin 2>/dev/null || true"
    )
    assert "squashfs" in modules_txt.stdout or "squashfs" in builtin.stdout, (
        "squashfs not available (not a module and not built-in)"
    )


def test_loop_module_available(sudo_host):
    modules_txt = sudo_host.run("grep '^loop ' /proc/modules 2>/dev/null || true")
    builtin = sudo_host.run(
        "grep loop /lib/modules/$(uname -r)/modules.builtin 2>/dev/null || true"
    )
    assert "loop" in modules_txt.stdout or "loop" in builtin.stdout, (
        "loop module not available"
    )


def test_apparmor_parser_present(host):
    assert host.file("/usr/sbin/apparmor_parser").exists


def test_aa_enabled_present(host):
    assert host.file("/usr/bin/aa-enabled").exists


def test_apparmor_enabled(sudo_host):
    result = sudo_host.run("aa-enabled")
    assert result.rc == 0, f"AppArmor not enabled: {result.stdout.strip()}"


def test_systemd_portabled_unit_present(host):
    unit = host.file("/usr/lib/systemd/system/systemd-portabled.service")
    alt = host.file("/lib/systemd/system/systemd-portabled.service")
    assert unit.exists or alt.exists, "systemd-portabled.service unit missing"

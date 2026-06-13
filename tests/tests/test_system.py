"""System-wide config from rootfs_overlay and skeleton: os-release, bash, profile, kernel modules."""


# ---------------------------------------------------------------------------
# OS identity (rootfs_overlay/etc/os-release)
# ---------------------------------------------------------------------------

def test_os_release_name(host):
    content = host.file("/etc/os-release").content_string
    assert 'NAME="Offline Lab OS"' in content


def test_os_release_id(host):
    assert "ID=offlinelab" in host.file("/etc/os-release").content_string


def test_os_release_pretty_name(host):
    assert "Offline Lab OS" in host.file("/etc/os-release").content_string


def test_machine_info_exists(host):
    assert host.file("/etc/machine-info").exists


def test_machine_info_chassis(host):
    content = host.file("/etc/machine-info").content_string
    assert "CHASSIS=embedded" in content


def test_machine_info_deployment(host):
    content = host.file("/etc/machine-info").content_string
    assert "DEPLOYMENT=production" in content


# ---------------------------------------------------------------------------
# Shell configuration (rootfs_overlay)
# ---------------------------------------------------------------------------

def test_bash_bashrc_exists(host):
    assert host.file("/etc/bash.bashrc").exists


def test_root_bashrc_exists(host):
    assert host.file("/root/.bashrc").exists


def test_profile_no_placeholder(host):
    content = host.file("/etc/profile").content_string
    assert "@PATH@" not in content, "/etc/profile has unsubstituted @PATH@ placeholder"


def test_offlinelab_sysinfo_profile(host):
    assert host.file("/etc/profile.d/offlinelab-sysinfo.sh").exists


def test_motd_exists(host):
    assert host.file("/etc/motd").exists


# ---------------------------------------------------------------------------
# Systemd system config (rootfs_overlay)
# ---------------------------------------------------------------------------

def test_framework_path_conf(host):
    assert host.file("/etc/systemd/system.conf.d/framework-path.conf").exists


def test_serial_getty_reset_conf(host):
    assert host.file(
        "/etc/systemd/system/serial-getty@.service.d/reset-tty.conf"
    ).exists


def test_eth_network_config(host):
    assert host.file("/etc/systemd/network/20-eth.network").exists


# ---------------------------------------------------------------------------
# Kernel modules and drivers (runtime)
# ---------------------------------------------------------------------------

def test_modules_dep_populated(host):
    result = host.run("wc -c /lib/modules/$(uname -r)/modules.dep")
    assert result.rc == 0, "modules.dep not found"
    size = int(result.stdout.split()[0])
    assert size > 0, "modules.dep is empty — host-kmod may lack XZ support"


def test_kmod_has_xz_support(host):
    result = host.run("strings /usr/bin/kmod | grep -o '+XZ'")
    assert result.rc == 0 and "+XZ" in result.stdout, (
        "Target kmod lacks XZ support — cannot load .ko.xz modules"
    )


def test_liblzma_present(host):
    result = host.run("find /usr/lib -name 'liblzma.so*' -print -quit")
    assert result.stdout.strip(), "liblzma not found — kmod cannot decompress .ko.xz"


# ---------------------------------------------------------------------------
# Sysctl parameters (runtime — applied from 99-offlinelab.conf at boot)
# ---------------------------------------------------------------------------

def test_sysctl_swappiness(host):
    result = host.run("sysctl -n vm.swappiness")
    assert result.rc == 0
    assert result.stdout.strip() == "10", f"vm.swappiness: expected 10, got {result.stdout.strip()}"


def test_sysctl_vfs_cache_pressure(host):
    result = host.run("sysctl -n vm.vfs_cache_pressure")
    assert result.rc == 0
    assert result.stdout.strip() == "150", (
        f"vm.vfs_cache_pressure: expected 150, got {result.stdout.strip()}"
    )


# ---------------------------------------------------------------------------
# Hosts and DNS
# ---------------------------------------------------------------------------

def test_etc_hosts_has_localhost(host):
    assert "localhost" in host.file("/etc/hosts").content_string


def test_nsswitch_conf_exists(host):
    assert host.file("/etc/nsswitch.conf").exists


# ---------------------------------------------------------------------------
# fzf
# ---------------------------------------------------------------------------

def test_fzf_binary_present(host):
    assert host.file("/usr/bin/fzf").exists


def test_fzf_executes(host):
    result = host.run("fzf --version")
    assert result.rc == 0, f"fzf --version failed: {result.stderr}"

"""offlinelab-zram: zram swap setup — files and runtime swap state."""


def test_zram_service_exists(host):
    assert host.file("/etc/systemd/system/zram-swap.service").exists


def test_zram_service_enabled(host):
    assert host.service("zram-swap").is_enabled


def test_init_zram_swap_executable(host):
    f = host.file("/usr/local/bin/init-zram-swap")
    assert f.exists
    assert f.mode & 0o111, "/usr/local/bin/init-zram-swap not executable"


def test_zram_modules_load_exists(host):
    assert host.file("/etc/modules-load.d/99-offlinelab-zram.conf").exists


def test_zram_modules_load_has_zram(host):
    content = host.file("/etc/modules-load.d/99-offlinelab-zram.conf").content_string
    assert "zram" in content


def test_zram_default_config_exists(host):
    assert host.file("/etc/default/zram-swap").exists


def test_zram_module_loaded(host):
    mods = host.file("/proc/modules").content_string
    builtin = host.run(
        "grep zram /lib/modules/$(uname -r)/modules.builtin 2>/dev/null || true"
    )
    assert "zram" in mods or "zram" in builtin.stdout, (
        "zram kernel module not loaded and not built-in"
    )


def test_zram_device_exists(host):
    assert host.file("/dev/zram0").exists, "/dev/zram0 not present"


def test_swap_is_active(host):
    result = host.run("swapon --show=NAME,TYPE --noheadings")
    assert result.rc == 0
    assert "zram" in result.stdout, (
        f"No zram swap active. swapon output:\n{result.stdout}"
    )

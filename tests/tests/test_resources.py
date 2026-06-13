"""offlinelab-resources: boot-time resource baseline measurement."""


def test_init_resources_executable(host):
    f = host.file("/usr/local/bin/init-resources")
    assert f.exists
    assert f.mode & 0o111, "/usr/local/bin/init-resources not executable"


def test_resources_service_exists(host):
    assert host.file("/etc/systemd/system/offlinelab-resources.service").exists


def test_resources_service_enabled(host):
    assert host.service("offlinelab-resources").is_enabled


def test_resources_service_is_oneshot(host):
    content = host.file("/etc/systemd/system/offlinelab-resources.service").content_string
    assert "Type=oneshot" in content


def test_resources_service_remain_after_exit(host):
    content = host.file("/etc/systemd/system/offlinelab-resources.service").content_string
    assert "RemainAfterExit=yes" in content


def test_resources_service_completed(host):
    # oneshot with RemainAfterExit — Result should be 'success' once it has run
    result = host.run("systemctl show -p Result --value offlinelab-resources.service")
    assert result.stdout.strip() == "success", (
        f"offlinelab-resources did not succeed: {result.stdout.strip()}"
    )

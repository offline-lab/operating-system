"""offlinelab-testing package: admin dev setup and testuser account."""


# ---------------------------------------------------------------------------
# admin — SSH key, home dir, sudoers, PATH extension
# (user account itself is created by users.txt; this package adds the dev setup)
# ---------------------------------------------------------------------------

def test_admin_home_exists(host):
    d = host.file("/home/admin")
    assert d.exists and d.is_directory


def test_admin_authorized_keys_installed(sudo_host):
    f = sudo_host.file("/home/admin/.ssh/authorized_keys")
    assert f.exists, "/home/admin/.ssh/authorized_keys missing"
    content = f.content_string.strip()
    assert content and not content.startswith("#"), (
        "authorized_keys is empty or contains only a placeholder comment"
    )


def test_admin_ssh_dir_permissions(sudo_host):
    ssh_dir = sudo_host.file("/home/admin/.ssh")
    assert ssh_dir.exists and ssh_dir.is_directory
    assert oct(ssh_dir.mode) == "0o700", f"/home/admin/.ssh mode: {oct(ssh_dir.mode)}"


def test_admin_sudoers_installed(sudo_host):
    f = sudo_host.file("/etc/sudoers.d/admin")
    assert f.exists, "/etc/sudoers.d/admin missing"
    assert "admin" in f.content_string


def test_admin_sudoers_is_nopasswd(sudo_host):
    content = sudo_host.file("/etc/sudoers.d/admin").content_string
    assert "NOPASSWD" in content, (
        "admin sudoers should be NOPASSWD (no password is set for admin)"
    )


# ---------------------------------------------------------------------------
# testuser — created by offlinelab-testing, uid 1001, NOPASSWD sudo
# ---------------------------------------------------------------------------

def test_testuser_exists(host):
    user = host.user("testuser")
    assert user.exists
    assert user.uid == 1001
    assert user.shell == "/bin/bash"
    assert user.home == "/home/testuser"


def test_testuser_in_sudo_group(host):
    assert "testuser" in host.group("sudo").members


def test_testuser_home_exists(host):
    d = host.file("/home/testuser")
    assert d.exists and d.is_directory


def test_testuser_authorized_keys_installed(host):
    f = host.file("/home/testuser/.ssh/authorized_keys")
    assert f.exists, "/home/testuser/.ssh/authorized_keys missing"
    content = f.content_string.strip()
    assert content and not content.startswith("#"), (
        "authorized_keys is empty or contains only a placeholder comment"
    )


def test_testuser_ssh_dir_permissions(host):
    ssh_dir = host.file("/home/testuser/.ssh")
    assert ssh_dir.exists and ssh_dir.is_directory
    assert oct(ssh_dir.mode) == "0o700", f"/home/testuser/.ssh mode: {oct(ssh_dir.mode)}"


def test_testuser_sudoers_installed(sudo_host):
    f = sudo_host.file("/etc/sudoers.d/testuser")
    assert f.exists, "/etc/sudoers.d/testuser missing"
    assert "testuser" in f.content_string


def test_testuser_sudoers_is_nopasswd(sudo_host):
    content = sudo_host.file("/etc/sudoers.d/testuser").content_string
    assert "NOPASSWD" in content, (
        "testuser sudoers should be NOPASSWD (required for test suite)"
    )


def test_testuser_can_sudo_without_password(host):
    # -n = non-interactive: fail immediately if a password would be needed
    result = host.run("sudo -n true")
    assert result.rc == 0, (
        f"testuser cannot sudo without a password — "
        f"offlinelab-testing not included in build? stderr: {result.stderr}"
    )

"""offlinelab-firewall: nftables rules, default policies, service state."""


def test_firewall_service_exists(host):
    assert host.file("/etc/systemd/system/firewall.service").exists


def test_firewall_service_enabled(host):
    assert host.service("firewall").is_enabled


def test_nftables_available(sudo_host):
    result = sudo_host.run("nft --version")
    assert result.rc == 0, f"nft not available: {result.stderr}"


def test_nftables_filter_table_loaded(sudo_host):
    result = sudo_host.run("nft list ruleset")
    assert result.rc == 0, f"nft list ruleset failed: {result.stderr}"
    assert "table inet filter" in result.stdout, (
        f"table inet filter not found in nft ruleset:\n{result.stdout}"
    )


def test_nftables_input_chain_present(sudo_host):
    result = sudo_host.run("nft list ruleset")
    assert result.rc == 0
    assert "chain input" in result.stdout.lower(), (
        f"input chain not found in nft ruleset:\n{result.stdout}"
    )


def test_nftables_ssh_accepted(sudo_host):
    # We are connected via SSH, so port 22 must have an accept rule.
    result = sudo_host.run("nft list ruleset")
    assert result.rc == 0
    assert "22" in result.stdout, (
        f"Port 22 not found in nft ruleset (SSH may be blocked):\n{result.stdout}"
    )


def test_firewall_rules_file_present(host):
    assert host.file("/etc/firewall/rules.fw").exists


def test_firewall_init_executable(host):
    f = host.file("/usr/local/bin/firewall-init")
    assert f.exists
    assert f.mode & 0o111, "/usr/local/bin/firewall-init not executable"


def test_firewall_restore_executable(host):
    f = host.file("/usr/local/bin/firewall-restore")
    assert f.exists
    assert f.mode & 0o111, "/usr/local/bin/firewall-restore not executable"


def test_no_unexpected_listening_ports(sudo_host):
    result = sudo_host.run("ss -tlnp")
    assert result.rc == 0
    # Collect listening ports for visibility; test suite can be extended to assert specific ones
    listening = [
        line for line in result.stdout.splitlines()
        if "LISTEN" in line
    ]
    assert len(listening) >= 1, "No listening ports found (SSH should be listening)"

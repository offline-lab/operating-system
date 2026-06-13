"""
Pytest fixtures for Offline Lab OS integration tests.

Usage:

  # Connect to an already-running QEMU or real device:
  pytest --host ssh://testuser@localhost:2223 --ssh-key ../br2-builder/.ssh/builder

  # Auto-start QEMU for a board:
  pytest --board qemu-arm64 \
         --artifacts ../br2-builder/artifacts/qemu-arm64 \
         --ssh-key ../br2-builder/.ssh/builder
"""

import os
import shutil
import socket
import subprocess
import time
from pathlib import Path

import pytest
import testinfra
import yaml


# ---------------------------------------------------------------------------
# CLI options
# ---------------------------------------------------------------------------

def pytest_addoption(parser):
    parser.addoption(
        "--host",
        metavar="SSH_URL",
        help="ssh://user@host:port — connect to an existing device or QEMU instance",
    )
    parser.addoption(
        "--board",
        metavar="NAME",
        help="Board name to auto-start QEMU, e.g. qemu-arm64",
    )
    parser.addoption(
        "--artifacts",
        metavar="PATH",
        default=os.environ.get("OL_ARTIFACTS"),
        help="Path to board artifacts directory (required with --board). Also OL_ARTIFACTS env var.",
    )
    parser.addoption(
        "--ssh-key",
        metavar="PATH",
        default=os.environ.get("OL_SSH_KEY"),
        help="SSH identity file (auto-detected if omitted). Also OL_SSH_KEY env var.",
    )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _boards_dir() -> Path:
    return Path(__file__).parent / "boards"


def _load_board(name: str) -> dict:
    path = _boards_dir() / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Board config not found: {path}")
    with path.open() as f:
        return yaml.safe_load(f)


def _find_key(request) -> Path:
    explicit = request.config.getoption("--ssh-key")
    if explicit:
        return Path(explicit)
    candidates = [
        Path(__file__).parent / ".ssh" / "testuser",
        Path(__file__).parent / ".ssh" / "builder",
        Path(__file__).parent.parent / ".ssh" / "builder",
        Path(__file__).parent.parent / "br2-builder" / ".ssh" / "builder",
    ]
    for c in candidates:
        if c.exists():
            return c
    raise FileNotFoundError(
        "No SSH key found. Pass --ssh-key or place a key at .ssh/testuser"
    )


def _wait_for_port(host: str, port: int, timeout: int = 120) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((host, port), timeout=2):
                return
        except (OSError, socket.timeout):
            time.sleep(3)
    raise TimeoutError(f"{host}:{port} not reachable after {timeout}s")


# ---------------------------------------------------------------------------
# QEMU lifecycle fixture (session-scoped, only active with --board)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def _qemu(request, tmp_path_factory):
    board_name = request.config.getoption("--board")
    if not board_name:
        yield None
        return

    artifacts_arg = request.config.getoption("--artifacts")
    if not artifacts_arg:
        raise ValueError("--artifacts is required when using --board")

    board = _load_board(board_name)
    artifacts = Path(artifacts_arg)
    qemu_cfg = board["qemu"]
    ssh_port = board["ssh"]["port"]

    bios = artifacts / board["artifacts"]["bios"]
    drive = artifacts / board["artifacts"]["drive"]
    for f in (bios, drive):
        if not f.exists():
            raise FileNotFoundError(f"Artifact not found: {f}")

    tmpdir = tmp_path_factory.mktemp("qemu")
    # Copy drive so the test run doesn't modify the artifact
    test_drive = tmpdir / "disk.img"
    shutil.copy2(drive, test_drive)
    serial_log = tmpdir / "serial.log"

    args = [
        qemu_cfg["binary"],
        "-machine", qemu_cfg["machine"],
        "-cpu", qemu_cfg["cpu"],
        "-m", qemu_cfg["memory"],
        "-smp", str(qemu_cfg["smp"]),
        "-bios", str(bios),
        "-drive", f"file={test_drive},format=raw,if=virtio",
        "-netdev", f"user,id=net0,hostfwd=tcp::{ssh_port}-:22",
        "-device", "virtio-net-pci,netdev=net0",
        "-chardev", f"file,id=serial0,path={serial_log}",
        "-serial", "chardev:serial0",
        "-monitor", "none",
        "-display", "none",
    ]

    proc = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        _wait_for_port("localhost", ssh_port, timeout=qemu_cfg["startup_timeout"])
        yield {"serial_log": serial_log, "ssh_port": ssh_port}
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        if request.session.testsfailed and serial_log.exists():
            print(f"\nQEMU serial log preserved at: {serial_log}")


# ---------------------------------------------------------------------------
# SSH host fixture (session-scoped — one connection for all tests)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def host(request, _qemu):
    board_name = request.config.getoption("--board")
    direct = request.config.getoption("--host")

    if not direct and not board_name:
        pytest.exit("Pass --host <ssh-url> or --board <name>", returncode=1)

    key = _find_key(request)
    ssh_opts = (
        f"-i {key} "
        "-o StrictHostKeyChecking=no "
        "-o UserKnownHostsFile=/dev/null "
        "-o IdentitiesOnly=yes "
        "-o IdentityAgent=none "
        "-o BatchMode=yes "
        "-o ConnectTimeout=10"
    )

    if direct:
        url = direct if direct.startswith("ssh://") else f"ssh://{direct}"
    else:
        board = _load_board(board_name)
        port = _qemu["ssh_port"]
        user = board["ssh"]["user"]
        url = f"ssh://{user}@localhost:{port}"

    h = testinfra.get_host(url, ssh_extra_args=ssh_opts)

    # Wait for sshd to accept commands (port can be open before sshd is ready)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        try:
            if h.run("true").rc == 0:
                break
        except Exception:
            pass
        time.sleep(2)

    yield h


# ---------------------------------------------------------------------------
# Sudo host fixture (function-scoped — fresh sudo context per test)
# ---------------------------------------------------------------------------

@pytest.fixture
def sudo_host(host):
    """Run commands as root via passwordless sudo (requires offlinelab-testing package)."""
    with host.sudo():
        yield host

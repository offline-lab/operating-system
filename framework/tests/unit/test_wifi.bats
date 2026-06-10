#!/usr/bin/env bats

load "../../bin/framework"

setup() {
    _stub_bin="$(mktemp -d)"

    # wpa_cli stub: strips -i IFACE and -p DIR flags, dispatches on the command
    cat >"${_stub_bin}/wpa_cli" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        -i | -p | -a) shift 2 ;;
        *) break ;;
    esac
done
cmd="$1"
case "${cmd}" in
    status)
        printf 'wpa_state=COMPLETED\nssid=TestNetwork\nip_address=192.168.1.42\n'
        ;;
    list_networks)
        printf 'network id / ssid / bssid / flags\n0\tTestNetwork\tany\t[CURRENT]\n'
        ;;
    scan_results)
        printf 'bssid\tfrequency\tsignal level\tflags\tssid\n'
        printf '00:11:22:33:44:55\t2412\t-50\t[WPA2-PSK]\tTestNet\n'
        ;;
    add_network) printf '1\n' ;;
    set_network | enable_network | save_config | reassociate) printf 'OK\n' ;;
    scan) printf 'OK\n' ;;
    *) printf 'UNKNOWN COMMAND\n'; exit 1 ;;
esac
exit 0
EOF
    chmod +x "${_stub_bin}/wpa_cli"

    # ip stub: returns canned output for addr show
    cat >"${_stub_bin}/ip" <<'EOF'
#!/bin/sh
printf '3: wlan0: <BROADCAST,MULTICAST,UP> mtu 1500\n'
printf '    inet 192.168.1.42/24 brd 192.168.1.255 scope global wlan0\n'
exit 0
EOF
    chmod +x "${_stub_bin}/ip"

    # priv::run pass-through stubs
    printf '#!/bin/sh\nexec "$@"\n' >"${_stub_bin}/sudo"
    printf '#!/bin/sh\nexec "$@"\n' >"${_stub_bin}/boxctl-su"
    chmod +x "${_stub_bin}/sudo" "${_stub_bin}/boxctl-su"

    export PATH="${_stub_bin}:${PATH}"
    export WIFI_INTERFACE="wlan0"

    import wifi
}

teardown() {
    rm -rf "${_stub_bin:-}"
}

##
## wifi::state
##

@test "wifi::state: returns wpa_supplicant state string" {
    result="$(wifi::state)"
    [ "${result}" = "COMPLETED" ]
}

##
## wifi::is_connected
##

@test "wifi::is_connected: returns 0 when state is COMPLETED" {
    run wifi::is_connected
    [ "${status}" -eq 0 ]
}

@test "wifi::is_connected: returns 1 when state is not COMPLETED" {
    cat >"${_stub_bin}/wpa_cli" <<'EOF'
#!/bin/sh
printf 'wpa_state=DISCONNECTED\n'
exit 0
EOF
    run wifi::is_connected
    [ "${status}" -eq 1 ]
}

##
## wifi::current_ssid
##

@test "wifi::current_ssid: returns the connected SSID" {
    result="$(wifi::current_ssid)"
    [ "${result}" = "TestNetwork" ]
}

##
## wifi::current_ip
##

@test "wifi::current_ip: returns IPv4 address" {
    result="$(wifi::current_ip)"
    [ "${result}" = "192.168.1.42" ]
}

##
## wifi::list_networks
##

@test "wifi::list_networks: returns output" {
    run wifi::list_networks
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "TestNetwork" ]]
}

##
## wifi::connect
##

@test "wifi::connect: returns 2 with fewer than 2 arguments" {
    run wifi::connect "OnlySSID"
    [ "${status}" -eq 2 ]
}

@test "wifi::connect: returns 0 with ssid and psk" {
    run wifi::connect "TestNetwork" "secret"
    [ "${status}" -eq 0 ]
}

##
## wifi::cli
##

@test "wifi::cli: returns 1 when wpa_cli missing" {
    local old_path="${PATH}"
    export PATH="${_stub_bin}/nonexistent:${PATH}"
    # Remove wpa_cli from stub bin temporarily
    mv "${_stub_bin}/wpa_cli" "${_stub_bin}/wpa_cli.bak"
    run wifi::cli status
    mv "${_stub_bin}/wpa_cli.bak" "${_stub_bin}/wpa_cli"
    export PATH="${old_path}"
    [ "${status}" -eq 1 ]
}

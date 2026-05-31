#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC2312

################################################################################
# Check files                                                                  #
################################################################################

#
# Check if file is a private key file
#

function ssl::is_key() {
    log::trace "${FUNCNAME[0]}: Checking if ${filename} is a private key"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    fs::exists "${filename}" || return 1

    if (fs::is_regex "${filename}" '-----BEGIN RSA PRIVATE KEY-----' "--" &&
        fs::is_regex "${filename}" '-----END RSA PRIVATE KEY-----' "--") ||
        (fs::is_regex "${filename}" '-----BEGIN ENCRYPTED PRIVATE KEY-----' "--" &&
            fs::is_regex "${filename}" '-----END ENCRYPTED PRIVATE KEY-----' "--") ||
        (fs::is_regex "${filename}" '-----BEGIN PRIVATE KEY-----' "--" &&
            fs::is_regex "${filename}" '-----END PRIVATE KEY-----' "--"); then
        return 0
    fi

    return 1
}

#
# Check if file is a certificate
#

function ssl::is_cert() {
    log::trace "${FUNCNAME[0]}: Checking if ${filename} is a certificate"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    fs::exists "${filename}" || return 1

    if (fs::is_regex "${filename}" '-----BEGIN X509 CERTIFICATE-----' "--" &&
        fs::is_regex "${filename}" '-----END X509 CERTIFICATE-----' "--") ||
        (fs::is_regex "${filename}" '-----BEGIN CERTIFICATE-----' "--" &&
            fs::is_regex "${filename}" '-----END CERTIFICATE-----' "--"); then
        return 0
    fi

    return 1
}

#
# Check if file is a certificate revocation list
#

function ssl::is_crl() {
    log::trace "${FUNCNAME[0]}: Checking if ${filename} is a certificate revocation list"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    fs::exists "${filename}" || return 1

    if fs::is_regex "${filename}" '-----BEGIN X509 CRL-----' "--" &&
        fs::is_regex "${filename}" '-----END X509 CRL-----' "--"; then
        return 0
    fi

    return 1
}

#
# Check if file is a certificate signing request
#

function ssl::is_csr() {
    log::trace "${FUNCNAME[0]}: Checking if ${filename} is a certificate signing request"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    fs::exists "${filename}" || return 1

    if (fs::is_regex "${filename}" '-----BEGIN NEW CERTIFICATE REQUEST-----' "--" &&
        fs::is_regex "${filename}" '-----END NEW CERTIFICATE REQUEST-----' "--") ||
        (fs::is_regex "${filename}" '-----BEGIN CERTIFICATE REQUEST-----' "--" &&
            fs::is_regex "${filename}" '-----END CERTIFICATE REQUEST-----' "--"); then
        return 0
    fi

    return 1
}

#
# Check if file is a dhparam file
#

function ssl::is_dhparam() {
    log::trace "${FUNCNAME[0]}: Checking if ${filename} is a dh parameter file"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    fs::exists "${filename}" || return 1

    if fs::is_regex "${filename}" '-----BEGIN DH PARAMETERS-----' "--" &&
        fs::is_regex "${filename}" '-----END DH PARAMETERS-----' "--"; then
        return 0
    fi

    return 1
}

#
# Check if file is a combined certificate and private key pem file
#

function ssl::is_combined() {
    log::trace "${FUNCNAME[0]}: Checking if file is a combined cert and key"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    fs::exists "${filename}" || return 1

    if ssl::is_key "${filename}" && ssl::is_cert "${filename}"; then
        return 0
    fi

    return 1
}

################################################################################
## Modulus check                                                              ##
################################################################################

#
# Get the modulus per type
#

function ssl::modulus::key() {
    log::trace "${FUNCNAME[0]}: Getting the modulus for key ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    fs::exists "${1}" || return 1

    openssl rsa -noout -modulus -in "${1}" | openssl md5
}

function ssl::modulus::cert() {
    log::trace "${FUNCNAME[0]}: Getting the modulus for cert ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    fs::exists "${1}" || return 1

    openssl x509 -noout -modulus -in "${1}" | openssl md5
}

function ssl::modulus::csr() {
    log::trace "${FUNCNAME[0]}: Getting the modulus for csr ${1}"

    [[ "${#}" -ne 1 ]] && return 2

    fs::exists "${1}" || return 1

    openssl req -noout -modulus -in "${1}" | openssl md5
}

#
# Retrieve the modulus of set of files
#

function ssl::modulus::get() {
    log::trace "${FUNCNAME[0]}: Retrieving the modulus for all files"

    [[ "${#}" -lt 1 ]] && return 2

    local files=("${@}")

    for filename in "${files[@]}"; do
        if ssl::is_key "${filename}"; then
            ssl::modulus::key "${filename}"
        fi

        if ssl::is_cert "${filename}"; then
            ssl::modulus::cert "${filename}"
        fi

        if ssl::is_csr "${filename}"; then
            ssl::modulus::csr "${filename}"
        fi
    done
}

#
# Retrieve the modulus and type of a set of files
#

function ssl::modulus::show() {
    log::trace "${FUNCNAME[0]}: Showing the modulus for all files"

    [[ "${#}" -lt 1 ]] && return 2

    local files=("${@}")

    for filename in "${files[@]}"; do
        if ssl::is_key "${filename}"; then
            printf "KEY %s: " "$(basename "${filename}")"
            ssl::modulus::key "${filename}"
        fi

        if ssl::is_cert "${filename}"; then
            printf "CRT %s: " "$(basename "${filename}")"
            ssl::modulus::cert "${filename}"
        fi

        if ssl::is_csr "${filename}"; then
            printf "CSR %s: " "$(basename "${filename}")"
            ssl::modulus::csr "${filename}"
        fi
    done
}

#
# Check if files have a matching modulus
#

function ssl::modulus::check() {
    log::trace "${FUNCNAME[0]}: Checking the modulus for all files"

    [[ "${#}" -lt 1 ]] && return 2

    local files=("${@}")

    local previous
    local current

    if ! current="$(ssl::modulus::get "${files[0]}" | sort -u)"; then
        log::error "${FUNCNAME[0]}: Failed to retrieve modulus for ${files[0]}"
    fi

    for file in "${files[@]}"; do
        previous="${current}"
        current="$(ssl::modulus::get "${file}" | sort -u)"

        if string::contains "d41d8cd98f00b204e9800998ecf8427e" "${current}"; then
            return 1
        fi

        if ! var::equals "${current}" "${previous}"; then
            return 1
        fi
    done

    return 0
}

################################################################################
## Generation                                                                 ##
################################################################################

#
# Read password file
#

function ssl::generate::read_password_file() {
    log::trace "${FUNCNAME[0]}: Reading passfile ${basedir}/.password"

    local -r basedir="${2}"

    var::is_empty "${basedir}" && return 2

    if ! fs::is_file "${basedir}/.password"; then
        log::error "${FUNCNAME[0]}: Passfile ${basedir}/.password not found!"
        return 1
    fi

    log::trace "${FUNCNAME[0]}: Reading passfile ${basedir}/.password"

    echo -n "$(<"${basedir}/.password")"

    return 0
}

#
# Create a directory structure prior to generating keypairs
#

function ssl::generate::create_directories() {
    log::trace "${FUNCNAME[0]}: Creating directory structure for ${type} in ${basedir}"

    local -r basedir="${2}"
    local -r type="${4}"

    var::is_empty "${basedir}" && return 2
    var::is_empty "${type}" && return 2

    log::trace "${FUNCNAME[0]}: Creating directory structure for ${type} in ${basedir}"

    mkdir -p "${basedir}"/{private,certs,certreqs,crl,newcerts}
    chmod "0700" "${basedir}/private"

    touch "${basedir}/${type}.index"
    echo 00 >"${basedir}/${type}.crlnum"

    return 0
}

#
# Create random serial
#

function ssl::generate::create_random_serial() {
    log::trace "${FUNCNAME[0]}: Creating a new random serial for ${type}"

    local -r basedir="${2}"
    local -r type="${4}"

    var::is_empty "${basedir}" && return 2
    var::is_empty "${type}" && return 2

    log::trace "${FUNCNAME[0]}: Creating a new random serial for ${type}"

    ## Create a random serial
    if ! openssl rand -hex 16 >"${basedir}/${type}.serial"; then
        log::error "${FUNCNAME[0]}: Failed to create ${basedir}/${type}.serial"
        return 1
    fi

    return 0
}

#
# Create CRL
#

function ssl::generate::create_crl() {
    log::trace "${FUNCNAME[0]}: Creating certificate revocation list"

    local -r basedir="${2:-}"
    local -r password="${4:-}"
    local -r type="${6:-}"

    local extra_args="${8:-}"
    local -a extra

    if ! var::is_empty "${extra_args}"; then
        IFS=" " read -r -a extra <<<"${extra_args}"
    fi

    var::is_empty "${basedir}" && return 2
    var::is_empty "${password}" && return 2
    var::is_empty "${type}" && return 2

    log::trace "${FUNCNAME[0]}: Create certificate revocation list"

    ## Create an empty CRL
    if ! chronic openssl ca \
        -gencrl \
        -passin "pass:${password}" \
        -out "${basedir}/${type}.crl"; then
        log::error "${FUNCNAME[0]}: Failed to create a certificate revocation list"
        return 1
    fi

    return 0
}

#
# Create private key
#

function ssl::generate::create_private_key() {
    log::trace "${FUNCNAME[0]}: Creating private key"

    local -r basedir="${2}"
    local -r password="${4}"
    local -r type="${6}"
    local -r curve="${8}"
    local extra_args="${10:-}"
    local -a extra

    if ! var::is_empty "${extra_args}"; then
        IFS=" " read -r -a extra <<<"${extra_args}"
    fi

    var::is_empty "${basedir}" && return 2
    var::is_empty "${password}" && return 2
    var::is_empty "${type}" && return 2
    var::is_empty "${curve}" && return 2

    log::trace "${FUNCNAME[0]}: Creating a private key"

    if ! chronic openssl ecparam \
        -genkey \
        -name "${curve}" \
        -out "${basedir}/private/${type}.key.tmp" \
        "${extra[@]}"; then
        log::error "${FUNCNAME[0]}: Failed to generate private ECDSA key"
        return 1
    fi

    log::trace "${FUNCNAME[0]}: Encrypting private key with password"

    if ! chronic openssl ec \
        -in "${basedir}/private/${type}.key.tmp" \
        -out "${basedir}/private/${type}.key" \
        -passout "pass:${password}" \
        -passin "pass:${password}" \
        -aes256; then
        log::error "${FUNCNAME[0]}: Failed to encrypt private key"
        return 1
    fi

    fs::is_file "${basedir}/private/${type}.key.tmp" &&
        rm "${basedir}/private/${type}.key.tmp"

    return 0
}

#
# Create cert request
#

function ssl::generate::create_csr() {
    log::trace "${FUNCNAME[0]}: Generating certificate signing request"

    local -r basedir="${2}"
    local -r password="${4}"
    local -r type="${6}"

    local outfile="${8:-}"
    local extra_args="${10:-}"

    local -a extra
    if ! var::is_empty "${extra_args}"; then
        IFS=" " read -r -a extra <<<"${extra_args}"
    fi

    var::is_empty "${outfile}" && outfile="${basedir}/certreqs/${type}.csr"

    log::trace "${FUNCNAME[0]}: Generating a cert request"

    # shellcheck disable=SC2068
    if ! chronic openssl req \
        -new \
        -sha256 \
        -key "${basedir}/private/${type}.key" \
        -passout "pass:${password}" \
        -passin "pass:${password}" \
        -out "${outfile}" \
        ${extra[@]}; then
        log::error "${FUNCNAME[0]}: Failed to generate cert request"
        return 1
    fi

    chmod 0600 "${basedir}/private/${type}.key"

    return 0
}

#
# Create a certificate from a csr
#

function ssl::generate::sign_csr() {
    log::trace "${FUNCNAME[0]}: Signing certificate signing request"

    local -r basedir="${2}"
    local -r password="${4}"
    local -r type="${6}"

    local -r extension="${8:-}"
    local extra_args="${10:-}"
    local -a extra

    if ! var::is_empty "${extra_args}"; then
        IFS=" " read -r -a extra <<<"${extra_args}"
    fi

    # shellcheck disable=SC2068
    local -a command=(
        openssl
        ca
        -batch
        -in "${basedir}/certreqs/${type}.csr"
        -out "${basedir}/certs/${type}.crt"
        -passin "pass:${password}"
        -extensions "${extension}"
        -days 3650
    )

    array::not_empty "${extra[@]}" && command+=("${extra[@]}")

    if ! chronic "${command[@]}"; then
        log::error "${FUNCNAME[0]}: Failed to generate ${type} cert"
        return 1
    fi

    return 0
}

################################################################################
## Info gathering / Troubleshooting                                           ##
################################################################################

#
# Get info for file
#

function ssl::get::file() {
    log::trace "${FUNCNAME[0]}: Reading file using openssl"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    depends::check::silent openssl || return 1

    if ! fs::is_file "${filename}"; then
        log::error "${FUNCNAME[0]}: Filename ${filename} not found!"
        return 1
    fi

    if ! openssl x509 \
        -noout \
        -subject \
        -issuer \
        -in "${filename}" \
        -inform pem \
        -text; then
        log::error "${FUNCNAME[0]}: Failed to read file ${filename} using openssl"
        return 1
    fi

    return 0
}

#
# Get info for host
#

function ssl::get::host() {
    log::trace "${FUNCNAME[0]}: Retrieving certificate from host using openssl"

    [[ "${#}" -lt 1 ]] && return 2

    local domain="${1}"
    local port="${2:-443}"
    local servername="${3:-${domain}}"

    depends::check::silent openssl || return 1

    local host
    if [[ "${domain}" != *":"* ]]; then
        host="${domain}:${port}"
    else
        host="${domain}"
    fi

    if ! echo QUIT |
        openssl s_client \
            -showcerts \
            -servername "${servername}" \
            -connect "${host}" \
            2>/dev/null |
        openssl x509 \
            -noout \
            -subject \
            -issuer \
            -inform pem \
            -text; then
        log::error "${FUNCNAME[0]}: Failed to retrieve certificate from ${servername} using openssl"
        return 1
    fi

    return 0
}

#
# Retrieve SSL certicate info
#

function ssl::info() {
    log::trace "${FUNCNAME[0]}: Retrieving SSL certificate info"

    [[ "${#}" -lt 1 ]] && return 2

    local domain="${1}"
    local port="${2:-443}"
    local servername="${3:-"${domain}"}"

    if fs::is_file "${domain}"; then
        ssl::get::file "${domain}"
    else
        ssl::get::host "${domain}" "${port}" "${servername}"
    fi

    return "${?}"
}

#
# Check a combined pemfile
#

function ssl::pem_chain() {
    log::trace "${FUNCNAME[0]}: Checking PEM chain"

    [[ "${#}" -ne 1 ]] && return 2

    local filename="${1}"

    fs::exists "${filename}" || return 1

    if ! ssl::is_combined "${filename}"; then
        log::error "${FUNCNAME[0]}: File ${filename} is not a pem file!"
        log::error "${FUNCNAME[0]}: Input file does not contain a private key and a certificate!"
        return 1
    fi

    log::input "${FUNCNAME[0]}: Getting modulus from cert and key"
    ssl::modulus::show "${filename}" | log::stdin

    if ! ssl::modulus::check "${filename}"; then
        log::error "${FUNCNAME[0]}: Modulus of cert and key do not match!"
        return 1
    fi

    openssl crl2pkcs7 \
        -nocrl \
        -certfile "${1}" \
        2>/dev/null |
        openssl pkcs7 \
            -print_certs \
            -text \
            -noout \
            2>/dev/null |
        awk '
            /Issuer:/ {
                tmp     = issuer
                issuer  = gensub(/^ *Issuer: */, "", 1, $0)
            }

            /Not Before:/ {
                tmp     = before
                before  = gensub(/^ *Not Before: */, "", 1, $0);
            }

             /Not After :/ {
                tmp     = after
                after   = gensub(/^ *Not After : */, "", 1, $0);
            }

            /DNS:/ {
                tmp     = domains
                domains = gensub(/^ *DNS:/, "DNS:", 1, $0);
            }

            /Subject:/ {
                tmp     = subject
                subject = gensub(/^ *Subject: */, "", 1, $0);

                printf("Subject    : %s\n",   subject);
                printf("Issuer     : %s\n",   issuer);
                printf("Not Before : %s\n",   before);
                printf("Not After  : %s\n\n", after);
            }

            END {
                printf("Domains    : %s\n",   domains);
            }
    '
}

################################################################################
#                                                                              #
################################################################################

# SSL — certificate and key validation

**Source:** `framework/library/ssl.sh`

Check if file is a private key file

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Check files

### `ssl::is_key`

> Checking if <value> is a private key

**Arguments:** exactly 1 argument(s)

---

### `ssl::is_cert`

> Checking if <value> is a certificate

**Arguments:** exactly 1 argument(s)

---

### `ssl::is_crl`

> Checking if <value> is a certificate revocation list

Check if file is a certificate revocation list

**Arguments:** exactly 1 argument(s)

---

### `ssl::is_csr`

> Checking if <value> is a certificate signing request

Check if file is a certificate signing request

**Arguments:** exactly 1 argument(s)

---

### `ssl::is_dhparam`

> Checking if <value> is a dh parameter file

**Arguments:** exactly 1 argument(s)

---

### `ssl::is_combined`

> Checking if file is a combined cert and key

Check if file is a combined certificate and private key pem file

**Arguments:** exactly 1 argument(s)

---

## Modulus check                                                              ##

### `ssl::modulus::key`

> Getting the modulus for key <value>

Get the modulus per type

**Arguments:** exactly 1 argument(s)

---

### `ssl::modulus::cert`

> Getting the modulus for cert <value>

**Arguments:** exactly 1 argument(s)

---

### `ssl::modulus::csr`

> Getting the modulus for csr <value>

**Arguments:** exactly 1 argument(s)

---

### `ssl::modulus::get`

> Retrieving the modulus for all files

Retrieve the modulus of set of files

**Arguments:** at least 1 argument(s)

---

### `ssl::modulus::show`

> Showing the modulus for all files

Retrieve the modulus and type of a set of files

**Arguments:** at least 1 argument(s)

---

### `ssl::modulus::check`

> Checking the modulus for all files

Check if files have a matching modulus

**Arguments:** at least 1 argument(s)

---

## Generation                                                                 ##

### `ssl::generate::read_password_file`

> Reading passfile <value>/.password

Read password file

---

### `ssl::generate::create_directories`

> Creating directory structure for <value> in <value>

Create a directory structure prior to generating keypairs

---

### `ssl::generate::create_random_serial`

> Creating a new random serial for <value>

Create random serial

---

### `ssl::generate::create_crl`

> Creating certificate revocation list

Create CRL

---

### `ssl::generate::create_private_key`

> Creating private key

Create private key

---

### `ssl::generate::create_csr`

> Generating certificate signing request

Create cert request

---

### `ssl::generate::sign_csr`

> Signing certificate signing request

Create a certificate from a csr

---

## Info gathering / Troubleshooting                                           ##

### `ssl::get::file`

> Reading file using openssl

Get info for file

**Arguments:** exactly 1 argument(s)

---

### `ssl::get::host`

> Retrieving certificate from host using openssl

Get info for host

**Arguments:** at least 1 argument(s)

---

### `ssl::info`

> Retrieving ssl certificate info

Retrieve SSL certicate info

**Arguments:** at least 1 argument(s)

---

### `ssl::pem_chain`

> Checking pem chain

Check a combined pemfile

**Arguments:** exactly 1 argument(s)

---

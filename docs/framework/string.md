# Strings — manipulation and comparison

**Source:** `framework/library/string.sh`

Convert a string to lowercase

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## String manipulation

### `string::lower`

> Converting string to lowercase

---

### `string::upper`

> Converting string to uppercase

---

### `string::replace`

> Replacing needle for string in haystack

Replace a substring in a string

**Arguments:** exactly 3 argument(s)

---

### `string::length`

> Retrieving the length of string

Return the lenght of a string

---

### `string::chomp`

Strip carriage return from string

---

### `string::trim`

> Stripping whitespace from string

Remove all superfluous whitespace

---

### `string::lstrip`

> Stripping char from left side of string

Strip a char from the left side of a string

---

### `string::rstrip`

> Stripping char from right side of string

Strip a char from the right side of a string

---

### `string::strip_prefix`

> Strip prefix <value> from string <value>

Strip a set of chars from the front of a string

**Arguments:** exactly 2 argument(s)

---

### `string::strip_suffix`

> Strip suffix <value> from string <value>

Strip a set of chars from the back of a string

**Arguments:** exactly 2 argument(s)

---

### `string::contains`

> Checking if string contains substring

Check if a string contains a set of chars

**Arguments:** exactly 2 argument(s)

---

### `string::startswith`

> Checking if string starts with pattern

Check if string starts with a set of chars

**Arguments:** exactly 2 argument(s)

---

### `string::endswith`

> Checking if string ends with pattern

Check if a string ends with a set of chars

**Arguments:** exactly 2 argument(s)

---

### `string::equals`

> Checking if string equals pattern

Check if string is equal to a set of chars

**Arguments:** exactly 2 argument(s)

---

### `string::not`

> Checking if string equals pattern

Check if string is not equal to a set of chars

**Arguments:** exactly 2 argument(s)

---

### `string::box`

> Printing a box around string

Print a box around a string

**Arguments:** at least 1 argument(s)

---

### `box`

---

# Variables — type and value checks

**Source:** `framework/library/var.sh`

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## VAR:: Stdin

### `var::is_stdin`

> Checking if a tty is allocated

---

## VAR:: Variable helpers

### `var::is_true`

> Checking if value is true

Check if var is true

---

### `var::is_false`

> Checking if value is false

Check if var is false

**Arguments:** exactly 1 argument(s)

---

### `var::is_bool`

> Checking if value is a boolean

Check if var is either true or false

**Arguments:** exactly 1 argument(s)

---

### `var::is_null`

> Checking if value is null

Check if var is null / none

**Arguments:** exactly 1 argument(s)

---

### `var::is_none`

> Checking if value is none

Check if var is null / none

**Arguments:** exactly 1 argument(s)

---

### `var::is_not_null`

> Checking if value is not null

Check if var is not null

**Arguments:** exactly 1 argument(s)

---

### `var::defined`

> Checking if variable is defined

Check if var is defined

**Arguments:** exactly 1 argument(s)

---

### `var::has_value`

> Checking if value is not empty

Check if var is not empty

**Arguments:** exactly 1 argument(s)

---

### `var::is_empty`

> Checking if variable is empty

Check if var is empty

**Arguments:** exactly 1 argument(s)

---

### `var::equals`

> Checking if variable equals string

Check if var is equal to

**Arguments:** exactly 2 argument(s)

---

### `var::matches`

> Checking if variable matches regex

Check if var matches a given regex

**Arguments:** exactly 2 argument(s)

---

### `var::is_numeric`

> Checking if variable is numeric

Check if var is numeric

**Arguments:** exactly 1 argument(s)

---

### `var::is_alphanumeric`

> Checking if variable is alphanumeric

Check if var is alphanumeric

**Arguments:** exactly 1 argument(s)

---

### `var::is_alpha`

> Checking if variable is alpha

Check if var is alpha

**Arguments:** exactly 1 argument(s)

---

### `var::is_int`

> Checking if variable is an integer

Check if var is an integer

**Arguments:** exactly 1 argument(s)

---

### `var::is_float`

> Checking if variable is a floatation

Check if var is a flotation

**Arguments:** exactly 1 argument(s)

---

## Boolean comparison

### `var::all`

> Checking if all vars are nonzero

Check if all are truthy

---

### `var::any`

> Check if any of the variables are nonzero

Check if one of the two is set

---

### `var::none`

> Check if all of the variables are none

Check if none are set

---

## Integer comparison

### `var::lt`

> Check if var1 is lower than var2

Check if var integer is lower than

**Arguments:** exactly 2 argument(s)

---

### `var::le`

> Checking if var1 is lower or equal than var2

Check if var integer is lower or equal

**Arguments:** exactly 2 argument(s)

---

### `var::gt`

> Checking if var1 is greater than var2

Check if var integer is greater than

**Arguments:** exactly 2 argument(s)

---

### `var::ge`

> Checking if var1 is greater or equal to var2

Check if var integer is greater or equal

**Arguments:** exactly 2 argument(s)

---

### `var::eq`

> Checking if var1 is equal to var2

Check if var integer is equal

**Arguments:** exactly 2 argument(s)

---

### `var::ne`

> Checking if var1 is not equal to var2

Check if var is integer not equal

**Arguments:** exactly 2 argument(s)

---

### `var::sum`

> Adding all vars

Add two vars

**Arguments:** at least 2 argument(s)

---

### `var::incr`

> Incrementing var

Increment var

**Arguments:** at least 1 argument(s)

---

### `var::decr`

> Decrementing var

Decrement var

**Arguments:** at least 1 argument(s)

---

### `var::typeofvar`

> Getting the type of input var

Get the type of the variable

**Arguments:** exactly 1 argument(s)

---

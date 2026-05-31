# Arrays — operations and predicates

**Source:** `framework/library/array.sh`

Get the length of an array

!!! note "Return codes"
    All functions return `0` on success, `1` on failure, `2` on wrong argument count.

## Array size comparison

### `array::length`

> Retrieving length of array

**Arguments:** at least 1 argument(s)

---

### `array::lt`

> Check if array size is less than n

**Arguments:** at least 1 argument(s)

---

### `array::le`

> Check if array is less than or equal to n

**Arguments:** at least 1 argument(s)

---

### `array::gt`

> Check if array size is greater than n

**Arguments:** at least 1 argument(s)

---

### `array::ge`

> Check if array size is greater than or equal to n

**Arguments:** at least 1 argument(s)

---

### `array::eq`

> Check if array size is equal to n

**Arguments:** at least 1 argument(s)

---

### `array::ne`

> Check if array size is not equal to n

**Arguments:** at least 1 argument(s)

---

## Array content comparison

### `array::contains`

> Check if array contains <value>

Check if array contains element

**Arguments:** at least 1 argument(s)

---

### `array::deduplicate`

> Deduplicating array

Remove duplicate fields from an array

**Arguments:** at least 1 argument(s)

---

### `array::is_empty`

> Check if array is empty

---

### `array::not_empty`

> Check if array is not empty

Check if an array is not empty

---

### `array::join`

> Joining array with delimiter

Join all fields in an array with a separator string or char

**Arguments:** at least 1 argument(s)

---

### `array::reverse`

> Reversing array

Reverse the order of an array

**Arguments:** at least 1 argument(s)

---

### `array::random_element`

> Printing random element from array

Retrieve a random element from an array

**Arguments:** at least 1 argument(s)

---

### `array::sort`

> Sorting array

Sort a numeric array

**Arguments:** at least 1 argument(s)

---

### `array::pop_by_name`

> Popping element <value> from array

Remove an element from an array by name

**Arguments:** at least 1 argument(s)

---

### `array::pop_by_position`

> Popping element <value> from array

Remove an element from an array by position

**Arguments:** at least 1 argument(s)

---

### `array::first`

> Printing first element from array

**Arguments:** at least 1 argument(s)

---

### `array::last`

> Printing last element from array

**Arguments:** at least 1 argument(s)

---

### `array::get`

> Printing <value>th element from array

**Arguments:** at least 1 argument(s)

---

### `array::all`

> Checking if all elements equal value

Return 0 if all of the elements are of value N

**Arguments:** at least 2 argument(s)

---

### `array::any`

> Checking if any element equals value

Return 0 if any of the elements is of value N

**Arguments:** at least 2 argument(s)

---

### `array::none`

> Checking if no elements equal value

Return 0 if none of the elements is of value N

**Arguments:** at least 2 argument(s)

---

### `array::allvalue`

> Checking if all elements match predicate

Return 0 if all elements are of the same value

**Arguments:** at least 2 argument(s)

---

### `array::alltrue`

> Checking if all elements are true

Return 0 if all elements are "true" or "0"

**Arguments:** at least 2 argument(s)

---

### `array::allfalse`

> Checking if all elements are false

Return 0 if all elements are

**Arguments:** at least 2 argument(s)

---

### `array::allnone`

> Checking if all elements are none

Return 0 if all elements are none or empty string

**Arguments:** at least 2 argument(s)

---

### `array::anyvalue`

> Checking if any elements match predicate

Return 0 if any elements are of the same value

**Arguments:** at least 2 argument(s)

---

### `array::anytrue`

> Checking if any elements are true

Return 0 if any elements are "true" or "0"

**Arguments:** at least 2 argument(s)

---

### `array::anyfalse`

> Checking if any elements are false

Return 0 if any elements are

**Arguments:** at least 2 argument(s)

---

### `array::anynone`

> Checking if any elements are none

Return 0 if any elements are none or empty string

**Arguments:** at least 2 argument(s)

---

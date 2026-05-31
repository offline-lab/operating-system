#!/usr/bin/env bats
# shellcheck disable=all

load "../../bin/framework"

#
# array::lenght
#

@test "Test that array::length returns the length of an array" {
    local -a array=(a a a b b b c c c)

    output="$(array::length "${array[@]}")"

    [[ "${output}" -eq 9 ]]
}

@test "Test that array::length returns 2 when invalid arguments" {
    local -a array=(a a a b b b c c c)

    run array::length
    [[ "${status}" -eq 2 ]]

    run array::length "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

#
# array::lt
#

@test "Test that array::lt returns 0 when size less than N" {
    local -a array=(a b c d)

    run array::lt 7 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::lt 6 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::lt 5 "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::lt returns 1 when size not less than N" {
    local -a array=(a b c d)

    run array::lt 3 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::lt 2 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::lt 1 "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test array::lt returns 2 when invalid arguments" {
    run array::lt
    [[ "${status}" -eq 2 ]]
}

#
# array::le
#

@test "Test that array::le returns 0 when size less than or equal to N" {
    local -a array=(a b c d)

    run array::le 6 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::le 5 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::le 4 "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::le returns 1 when size not less than or equal to N" {
    local -a array=(a b c d)

    run array::le 3 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::le 2 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::le 1 "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test array::le returns 2 when invalid arguments" {
    run array::le
    [[ "${status}" -eq 2 ]]
}

#
# array::gt
#

@test "Test that array::gt returns 0 when size greater than N" {
    local -a array=(a b c d)

    run array::gt 1 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::gt 2 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::gt 3 "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::gt returns 1 when size not greater than N" {
    local -a array=(a b c d)

    run array::gt 5 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::gt 6 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::gt 7 "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test array::gt returns 2 when invalid arguments" {
    run array::gt
    [[ "${status}" -eq 2 ]]
}

#
# array::ge
#

@test "Test that array::ge returns 0 when size greater than or equal to N" {
    local -a array=(a b c d)

    run array::ge 2 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::ge 3 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::ge 4 "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::ge returns 1 when size not greater than or equal to N" {
    local -a array=(a b c d)

    run array::ge 5 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::ge 6 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::ge 7 "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test array::ge returns 2 when invalid arguments" {
    run array::ge
    [[ "${status}" -eq 2 ]]
}

#
# array::eq
#

@test "Test that array::eq returns 0 when size equal to N" {
    local -a array=(a b c d)

    run array::eq 4 "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::eq returns 1 when size not equal to N" {
    local -a array=(a b c d)

    run array::eq 1 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::eq 2 "${array[@]}"
    [[ "${status}" -eq 1 ]]
    run array::eq 100 "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test array::eq returns 2 when invalid arguments" {
    run array::eq
    [[ "${status}" -eq 2 ]]
}

#
# array::ne
#

@test "Test that array::ne returns 0 when size not equal to N" {
    local -a array=(a b c d)

    run array::ne 1 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::ne 2 "${array[@]}"
    [[ "${status}" -eq 0 ]]
    run array::ne 3 "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::ne returns 1 when size equal to N" {
    local -a array=(a b c d)

    run array::ne 4 "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test array::ne returns 2 when invalid arguments" {
    run array::ne
    [[ "${status}" -eq 2 ]]
}

#
# array::contains
#

@test "Test that array::contains returns 0 when needle in haystack" {
    local -a array=(a b c d)

    run array::contains "a" "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::contains returns 1 when needle not in haystack" {
    local -a array=(a b c d)

    run array::contains "e" "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::contains returns 2 when invalid arguments" {
    run array::contains
    [[ "${status}" -eq 2 ]]
}

#
# array::deduplicate
#

@test "Test that array::deduplicate dedups an array" {
    local -a array=(a a a b b b c c c)

    output=($(array::deduplicate "${array[@]}"))

    [[ "${output[0]}" == "a" ]]
    [[ "${output[1]}" == "b" ]]
    [[ "${output[2]}" == "c" ]]
}

@test "Test that array::deduplicate returns 2 when invalid arguments" {
    local -a array=(a a a b b b c c c)

    run array::deduplicate
    [[ "${status}" -eq 2 ]]

    run array::deduplicate "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

#
# array::is_empty
#

@test "Test that array::is_empty returns 0 if array is empty" {
    local -a array

    run array::is_empty "${array[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::is_empty returns 1 if array is not empty" {
    local -a array
    array=(1 2 3 4)

    run array::is_empty "${array[@]}"
    [[ "${status}" -eq 1 ]]
}

#
# array::join
#

@test "Test that array::join joins 2 arrays" {
    local -a array1=(1 2 3 4)

    output="$(array::join - "${array1[@]}")"
    [[ "$output" == "1-2-3-4" ]]
}

@test "Test that array::join returns 2 when invalid arguments" {
    run array::join
    [[ "${status}" -eq 2 ]]

    run array::join - a b c d
    [[ "${status}" -eq 0 ]]
}

#
# array::reverse
#

@test "Test that array::reverse reverses an array" {
    local -a array1=(1 2 3 4)
    output=($(array::reverse "${array1[@]}"))

    [[ "${output[0]}" == "4" ]]
    [[ "${output[1]}" == "3" ]]
    [[ "${output[2]}" == "2" ]]
    [[ "${output[3]}" == "1" ]]
}

@test "Test that array::reverse returns 2 when invalid arguments" {
    run array::reverse
    [[ "${status}" -eq 2 ]]

    run array::reverse 1 2 3 4
    [[ "${status}" -eq 0 ]]
}

#
# array::random_element
#

@test "Test that array::random_element returns 2 when invalid arguments" {
    run array::random_element
    [[ "${status}" -eq 2 ]]
}

@test "Test that array::random_element returns 0 when valid arguments" {
    local -a array1=(1 2 3 4)

    run array::random_element "${array1[@]}"
    [[ "${status}" -eq 0 ]]
}

#
# array::sort
#

@test "Test that array::sort sorts an array" {
    local -a array1=(a c b d)
    output=($(array::sort "${array1[@]}"))

    [[ "${output[0]}" == "a" ]]
    [[ "${output[1]}" == "b" ]]
    [[ "${output[2]}" == "c" ]]
    [[ "${output[3]}" == "d" ]]
}

@test "Test that array::sort returns 2 when invalid arguments" {
    run array::sort
    [[ "${status}" -eq 2 ]]

    run array::sort a b c d
    [[ "${status}" -eq 0 ]]
}

#
# array::sort-r
#

@test "Test that array::sort-r reverse sorts an array" {
    local -a array1=(a c b d)
    output=($(array::sort-r "${array1[@]}"))

    [[ "${output[0]}" == "d" ]]
    [[ "${output[1]}" == "c" ]]
    [[ "${output[2]}" == "b" ]]
    [[ "${output[3]}" == "a" ]]
}

@test "Test that array::sort-r returns 2 when invalid arguments" {
    run array::sort-r
    [[ "${status}" -eq 2 ]]

    run array::sort-r a b c d
    [[ "${status}" -eq 0 ]]
}

#
# array::pop_by_name
#

@test "Test that array::pop_by_name removes a named element from an array" {
    local -a array1=(a b c d)
    output=($(array::pop_by_name a "${array1[@]}"))

    [[ "${output[0]}" == "b" ]]
    [[ "${output[1]}" == "c" ]]
    [[ "${output[2]}" == "d" ]]

    local -a array1=(a b c d)
    output=($(array::pop_by_name e "${array1[@]}"))

    [[ "${output[0]}" == "a" ]]
    [[ "${output[1]}" == "b" ]]
    [[ "${output[2]}" == "c" ]]
    [[ "${output[3]}" == "d" ]]

    local -a array1=(a b c d a b c d)
    output=($(array::pop_by_name a "${array1[@]}"))

    [[ "${output[0]}" == "b" ]]
    [[ "${output[1]}" == "c" ]]
    [[ "${output[2]}" == "d" ]]
    [[ "${output[3]}" == "b" ]]
    [[ "${output[4]}" == "c" ]]
    [[ "${output[5]}" == "d" ]]
}

@test "Test that array::pop_by_name returns 2 when invalid arguments" {
    run array::pop_by_name
    [[ "${status}" -eq 2 ]]

    run array::pop_by_name a a b c d
    [[ "${status}" -eq 0 ]]
}

#
# array::pop_by_position
#

@test "Test that array::pop_by_position removes a named element from an array" {
    local -a array1=(a b c d)

    output=($(array::pop_by_position 1 "${array1[@]}"))

    [[ "${output[0]}" == "a" ]]
    [[ "${output[1]}" == "c" ]]
    [[ "${output[2]}" == "d" ]]

    output=($(array::pop_by_position 2 "${array1[@]}"))

    [[ "${output[0]}" == "a" ]]
    [[ "${output[1]}" == "b" ]]
    [[ "${output[2]}" == "d" ]]

    output=($(array::pop_by_position 3 "${array1[@]}"))

    [[ "${output[0]}" == "a" ]]
    [[ "${output[1]}" == "b" ]]
    [[ "${output[2]}" == "c" ]]

    output=($(array::pop_by_position 5 "${array1[@]}"))

    [[ "${output[0]}" == "a" ]]
    [[ "${output[1]}" == "b" ]]
    [[ "${output[2]}" == "c" ]]
    [[ "${output[3]}" == "d" ]]
}

@test "Test that array::pop_by_position returns 2 when invalid arguments" {
    run array::pop_by_position
    [[ "${status}" -eq 2 ]]
}

@test "Test that array::pop_by_position returns 2 when non numeric pos" {
    local -a array1=(a b c d a b c d)
    run array::pop_by_position a "${array[@]}"
    [[ "${status}" -eq 2 ]]
}

#
# array::first
#

@test "Test that array::first prints the first element of an array" {
    local -a array1=(a b c d)

    output="$(array::first "${array1[@]}")"
    [[ "${output}" == "a" ]]
}

@test "Test that array::first returns 2 when invalid arguments" {
    run array::first
    [[ "${status}" -eq 2 ]]

    run array::first a b c d
    [[ "${status}" -eq 0 ]]
}

#
# array::last
#

@test "Test that array::last prints the last element of an array" {
    local -a array1=(a b c d)

    output="$(array::last "${array1[@]}")"
    [[ "${output}" == "d" ]]
}

@test "Test that array::last returns 2 when invalid arguments" {
    run array::last
    [[ "${status}" -eq 2 ]]

    run array::last a b c d
    [[ "${status}" -eq 0 ]]
}

#
# array::get
#

@test "Test that array::get prints the Nth element of an array" {
    local -a array1=(a b c d)

    output="$(array::get 0 "${array1[@]}")"
    [[ "${output}" == "a" ]]

    output="$(array::get 1 "${array1[@]}")"
    [[ "${output}" == "b" ]]

    output="$(array::get 2 "${array1[@]}")"
    [[ "${output}" == "c" ]]

    output="$(array::get 3 "${array1[@]}")"
    [[ "${output}" == "d" ]]
}

@test "Test that array::get returns 2 when invalid arguments" {
    run array::get
    [[ "${status}" -eq 2 ]]

    run array::get 1 a b c d
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::get returns 2 when non numeric pos" {
    local -a array1=(a b c d a b c d)

    run array::get a "${array1[@]}"

    [[ "${status}" -eq 2 ]]
}

#
# array::all
#
@test "Test that array::all returns 0 if all of the elements are of value N" {
    local -a array1=(none none none none)

    run array::all none "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(a a a a a)

    run array::all a "${array2[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::all returns 1 if not all of the elements are of value N" {
    local -a array1=(none n none none)

    run array::all none "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(a b a a a)

    run array::all a "${array2[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::all returns 2 if not enough arguments" {
    run array::all

    [[ "${status}" -eq 2 ]]
}

#
# array::any
#
@test "Test that array::any returns 0 if any of the elements is of value N" {
    local -a array1=(none n none none)

    run array::any n "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(a b a a a)

    run array::any b "${array2[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::any returns 1 if not any of the elements is of value N" {
    local -a array1=(none n none none)

    run array::any x "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(a b a a a)

    run array::any c "${array2[@]}"
    [[ "${status}" -eq 1 ]]

}

@test "Test that array::any returns 2 if not enough arguments" {
    run array::any

    [[ "${status}" -eq 2 ]]
}

#
# array::none
#

@test "Test that array::none returns 0 if none of the elements is of value N" {
    local -a array1=(none n none none)

    run array::none x "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(a b a a a)

    run array::none c "${array2[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::none returns 1 if not none of the elements is of value N" {
    local -a array1=(none n none none)

    run array::none n "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(a b a a a)

    run array::none b "${array2[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::none returns 2 if not enough arguments" {
    run array::none

    [[ "${status}" -eq 2 ]]
}

#
# array::anyvalue
#
@test "Test that array::anyvalue returns 0 if any elements are of the same value" {

    local -a array1=("" "" true "" )
    run array::anyvalue var::is_true "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(0 0 0 0 0 0 0 1)
    run array::anyvalue var::is_true "${array2[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(1 1 1 1 1 1 1 0)
    run array::anyvalue var::is_false "${array2[@]}"
    [[ "${status}" -eq 0 ]]


    local -a array3=("" "" "" "" a)
    run array::anyvalue var::has_value "${array3[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array4=(aa bb cc dd "")
    run array::anyvalue var::is_empty "${array4[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::anyvalue returns 1 if not any elements are of the same value" {
    local -a array1=(false false false false)
    run array::anyvalue var::is_true "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(1 1 1 1 1 1 )
    run array::anyvalue var::is_false "${array2[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(0 0 0 0 0 0 )
    run array::anyvalue var::is_true "${array2[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array3=("" "" "" "")
    run array::anyvalue var::has_value "${array3[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array4=(a a a a)
    run array::anyvalue var::is_empty "${array4[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::anyvalue returns 2 if not enough arguments" {
    run array::anyvalue

    [[ "${status}" -eq 2 ]]
}

#
# array::anytrue
#
@test "Test that array::anytrue returns 0 if any elements are true or 1" {
    local -a array1=(true false false false false)

    run array::anytrue "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(0 0 0 0 0 0 0 1)

    run array::anytrue "${array2[@]}"
    [[ "${status}" -eq 0 ]]

}

@test "Test that array::anytrue returns 1 if not any elements are true or 1" {
    local -a array1=(false false false false )

    run array::anytrue "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(0 0 0 0 0 0 0 )

    run array::anytrue "${array2[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::anytrue returns 2 if not enough arguments" {
    run array::anytrue

    [[ "${status}" -eq 2 ]]
}

#
# array::anyfalse
#
@test "Test that array::anyfalse returns 0 if any elements are false or 0" {
    local -a array1=(true true false true )

    run array::anyfalse "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(1 1 1 1 0 1 1 )

    run array::anyfalse "${array2[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::anyfalse returns 1 if not any elements are false or 0" {
    local -a array1=(true true true true )

    run array::anyfalse "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(1 1 1 1 1 1 1 )

    run array::anyfalse "${array2[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::anyfalse returns 2 if not enough arguments" {
    run array::anyfalse

    [[ "${status}" -eq 2 ]]
}

#
# array::anynone
#
@test "Test that array::anynone returns 0 if any elements are none or empty string" {
    local -a array1=(a a a a "")

    run array::anynone "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(a a a a a a none)

    run array::anynone "${array2[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::anynone returns 1 if not any elements are none or empty string" {
    local -a array1=(a a a a )

    run array::anynone "${array1[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::anynone returns 2 if not enough arguments" {
    run array::anynone

    [[ "${status}" -eq 2 ]]
}

#
# array::allvalue
#
@test "Test that array::allvalue returns 0 if all elements are of the same value" {

    local -a array1=("true" "true" "true" "true" )
    run array::allvalue var::is_true "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(1 1 1 1 1 1 1 )
    run array::allvalue var::is_true "${array2[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(0 0 0 0 0 0 0 )
    run array::allvalue var::is_false "${array2[@]}"
    [[ "${status}" -eq 0 ]]


    local -a array3=(a a a a a)
    run array::allvalue var::has_value "${array3[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array4=("" "" "" "" "")
    run array::allvalue var::is_empty "${array4[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::allvalue returns 1 if not all elements are of the same value" {
    local -a array1=("true" "true" "true" "false" )
    run array::allvalue var::is_true "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(1 0 1 1 1 1 1 )
    run array::allvalue var::is_true "${array2[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(0 1 0 0 0 0 0 )
    run array::allvalue var::is_false "${array2[@]}"
    [[ "${status}" -eq 1 ]]


    local -a array3=(a "" a a a)
    run array::allvalue var::has_value "${array3[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array4=("" a "" "" "")
    run array::allvalue var::is_empty "${array4[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::allvalue returns 2 if not enough arguments" {
    run array::allvalue

    [[ "${status}" -eq 2 ]]
}

#
# array::alltrue
#
@test "Test that array::alltrue returns 0 if all elements are true or 1" {
    local -a array1=(true true true true )

    run array::alltrue "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(1 1 1 1 1 1 1 )

    run array::alltrue "${array2[@]}"
    [[ "${status}" -eq 0 ]]

}

@test "Test that array::alltrue returns 1 if not all elements are true or 1" {
    local -a array1=(true false true true )

    run array::alltrue "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(1 1 1 1 0 1 1 )

    run array::alltrue "${array2[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::alltrue returns 2 if not enough arguments" {
    run array::alltrue

    [[ "${status}" -eq 2 ]]
}

#
# array::allfalse
#
@test "Test that array::allfalse returns 0 if all elements are false or 0" {
    local -a array1=(false false false false )

    run array::allfalse "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=(0 0 0 0 0 0 0 )

    run array::allfalse "${array2[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::allfalse returns 1 if not all elements are false or 0" {
    local -a array1=(false true false false )

    run array::allfalse "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=(0 0 0 0 0 1 0 )

    run array::allfalse "${array2[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::allfalse returns 2 if not enough arguments" {
    run array::allfalse

    [[ "${status}" -eq 2 ]]
}

#
# array::allnone
#
@test "Test that array::allnone returns 0 if all elements are none or empty string" {
    local -a array1=(none none none none)

    run array::allnone "${array1[@]}"
    [[ "${status}" -eq 0 ]]

    local -a array2=("" "" "" "" "" "" "")

    run array::allnone "${array2[@]}"
    [[ "${status}" -eq 0 ]]
}

@test "Test that array::allnone returns 1 if not all elements are none or empty string" {
    local -a array1=(none a none none )

    run array::allnone "${array1[@]}"
    [[ "${status}" -eq 1 ]]

    local -a array2=("" "" a "" "" "" "" )

    run array::allnone "${array2[@]}"
    [[ "${status}" -eq 1 ]]
}

@test "Test that array::allnone returns 2 if not enough arguments" {
    run array::allnone

    [[ "${status}" -eq 2 ]]
}

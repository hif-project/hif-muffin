# -----------------------------------------------------------------------------
# @brief  : Regression (#22) for the generated-text assertion helper.
#
#           The round-trip tests assert that regenerated HDL contains a given
#           expression. Written as a literal substring match, such an assertion
#           reports a failure whenever the emitting printer chooses to break a
#           line inside the expression -- even though whitespace there is
#           insignificant and the design is unchanged.
#
#           That is what happened in #22: hif-backend#61 widened a one-bit
#           value from `0` to `1'b0`, the enclosing line crossed the printer's
#           wrap column, and `a & b` came out as `(a\n     & b)`. The design
#           still compiled and still behaved identically; only the test broke.
#
#           This test pins the helper's contract directly, on fixed strings,
#           rather than through whatever the backend happens to emit today --
#           so the property survives the next formatting change too.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

include(${CMAKE_CURRENT_LIST_DIR}/hif_text_assert.cmake)

set(failures 0)

# A local mirror of the helper's matching rule, so this test can assert both
# that a match is found *and* that one is not, without aborting the script.
function(expect_match content expected description)
    hif_text_normalize("${content}" _c)
    hif_text_normalize("${expected}" _e)
    string(FIND "${_c}" "${_e}" _found)
    if(_found EQUAL -1)
        message(SEND_ERROR "EXPECTED MATCH but found none: ${description}")
        math(EXPR failures "${failures} + 1")
        set(failures ${failures} PARENT_SCOPE)
    endif()
endfunction()

function(expect_no_match content expected description)
    hif_text_normalize("${content}" _c)
    hif_text_normalize("${expected}" _e)
    string(FIND "${_c}" "${_e}" _found)
    if(NOT _found EQUAL -1)
        message(SEND_ERROR "EXPECTED NO MATCH but found one: ${description}")
        math(EXPR failures "${failures} + 1")
        set(failures ${failures} PARENT_SCOPE)
    endif()
endfunction()

# --- The exact #22 failure ------------------------------------------------
#
# Verbatim from the regenerated and2.v that failed against hif-backend 2c09a44.

set(wrapped "    always @( a, b, muffinMutPort ) begin
        y <= ((muffinMutPort == 1) ? (1'b0) : (muffinMutPort == 2) ? (1'b1) : (a
             & b));
    end")

expect_match("${wrapped}" "a & b" "#22: `a & b` wrapped after the operand")
expect_match("${wrapped}" "muffinMutPort == 1" "#22: comparison on one line")
expect_match("${wrapped}" "muffinMutPort == 2" "#22: comparison on one line")

# The pre-#22 formatting must keep matching: the fix is about tolerating both.
set(unwrapped "        y <= ((muffinMutPort == 1) ? (0) : (muffinMutPort == 2) ? (1) : (a & b));")
expect_match("${unwrapped}" "a & b" "pre-#22 formatting still matches")

# --- Insignificant-whitespace variants ------------------------------------

expect_match("y <= (a&b);" "a & b" "operator spacing removed")
expect_match("y <= (a\t&\tb);" "a & b" "tabs around the operator")
expect_match("assign o = a\n    &\n    b;" "a & b" "operand and operator both wrapped")
expect_match("parameter WIDTH\n    = 4;" "parameter WIDTH = 4" "declaration wrapped")
expect_match("reg [WIDTH -\n    1:0] q;" "[WIDTH - 1:0]" "range wrapped")

# --- The assertion must still be able to fail -----------------------------
#
# Whitespace-insensitivity must not become "matches anything". Without these,
# a helper that always reported success would pass the checks above.

expect_no_match("y <= (a | b);" "a & b" "a different operator must not match")
expect_no_match("y <= (a & c);" "a & b" "a different operand must not match")
expect_no_match("y <= (b & a);" "a & b" "reversed operands must not match")
expect_no_match("parameter WIDTHX = 4;" "parameter WIDTH = 4" "a longer identifier must not match")
expect_no_match("" "a & b" "empty content must not match")

if(failures GREATER 0)
    message(FATAL_ERROR "${failures} text-assertion helper check(s) failed.")
endif()

message(STATUS "Text-assertion helper test passed.")

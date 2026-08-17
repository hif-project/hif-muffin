# -----------------------------------------------------------------------------
# @brief  : Whitespace-tolerant assertions over generated text.
#
#           Tests here check that regenerated HDL (or a generated JSON report)
#           contains a particular expression. Matched as a literal substring,
#           such a check is really a check on the emitting printer's layout: it
#           fails whenever the printer breaks a line inside the expression, or
#           changes how it pads an operator, even though the emitted artifact
#           is unchanged in meaning.
#
#           #22 is the worked example. hif-backend#61 widened a one-bit value
#           from `0` to `1'b0`; the enclosing line crossed the wrap column; and
#           `a & b` was emitted as `(a\n     & b)`. The design still compiled
#           and still simulated identically, but `and2_round_trip` failed.
#
#           These helpers compare with every whitespace character removed from
#           both sides, so an assertion constrains the token sequence and not
#           the layout. Whitespace is insignificant between HDL tokens, so this
#           does not weaken what the assertions actually test: token *order*,
#           spelling and adjacency are all still enforced -- `a & b` does not
#           match `a | b`, `a & c` or `b & a`.
#
#           Removing whitespace entirely, rather than collapsing runs to a
#           single space, also makes a match independent of operator padding,
#           which is the other formatting axis a printer change tends to move.
#           This mirrors what tests/fault_enumeration_test.cmake already does
#           to the fault JSON before matching records in it.
#
#           Deliberately *not* applied to assertions that already use a
#           whitespace-tolerant regex (hierarchical_behavioral,
#           mutport_sensitivity) or that already compact their input
#           (fault_enumeration).
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

# Strip every whitespace character from `in_text`, storing the result in the
# variable named by `out_var` in the caller's scope.
function(hif_text_normalize in_text out_var)
    string(REGEX REPLACE "[ \t\r\n]+" "" _normalized "${in_text}")
    set(${out_var} "${_normalized}" PARENT_SCOPE)
endfunction()

# Fail with a diagnostic unless `content` contains `expected`, comparing both
# with whitespace removed. `what` names the artifact under test, so the failure
# reads the same way the old literal-substring failure did.
function(hif_assert_text_contains content expected what)
    hif_text_normalize("${content}" _content_normalized)
    hif_text_normalize("${expected}" _expected_normalized)

    string(FIND "${_content_normalized}" "${_expected_normalized}" _found_at)
    if(_found_at EQUAL -1)
        message(FATAL_ERROR
            "${what} missing expected content: ${expected}\n"
            "(compared ignoring whitespace, so this is a real absence and not a line break)\n"
            "Full content:\n${content}")
    endif()
endfunction()

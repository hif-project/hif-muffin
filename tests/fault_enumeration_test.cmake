# -----------------------------------------------------------------------------
# @brief  : Checks that muffin --list-faults enumerates the right number of
#           faults, with the right per-fault metadata, for a single-location
#           design of a known width.
# @details Asserts the exact record for every bit rather than just the count,
#          so a design reported at the wrong width cannot pass by accident.
#          Expects the design to contain exactly one injectable location, so
#          fault ids are 2*bit+1 (SA0) and 2*bit+2 (SA1).
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

foreach(required
    MUFFIN_EXECUTABLE VERILOG2HIF_EXECUTABLE FIXTURE DESIGN WORK_DIR EXPECTED_SIGNAL EXPECTED_WIDTH)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required variable: ${required}")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

# --- Verilog -> HIF ------------------------------------------------------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -o ${DESIGN} ${FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif failed with exit code ${result}")
endif()

# --- Enumerate -----------------------------------------------------------

set(FAULTS_JSON ${WORK_DIR}/faults.json)
execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/${DESIGN}.hif.xml --list-faults ${FAULTS_JSON}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --list-faults failed with exit code ${result}")
endif()

file(READ ${FAULTS_JSON} faults_json_content)

# Collapse whitespace so records can be matched as compact substrings,
# independent of how the JSON writer happens to indent them.
string(REGEX REPLACE "[ \t\r\n]" "" compact "${faults_json_content}")

# --- Fault count ---------------------------------------------------------

math(EXPR expected_count "2 * ${EXPECTED_WIDTH}")

string(REGEX MATCHALL "\"id\":[0-9]+" id_matches "${compact}")
list(LENGTH id_matches actual_count)

if(NOT actual_count EQUAL expected_count)
    message(FATAL_ERROR
        "Expected ${expected_count} faults (2 per bit of a ${EXPECTED_WIDTH}-bit signal) but found "
        "${actual_count}.\nFull content:\n${faults_json_content}")
endif()

# --- Per-bit records -----------------------------------------------------

math(EXPR last_bit "${EXPECTED_WIDTH} - 1")

foreach(bit RANGE 0 ${last_bit})
    math(EXPR sa0_id "2 * ${bit} + 1")
    math(EXPR sa1_id "2 * ${bit} + 2")

    set(sa0_record
        "{\"id\":${sa0_id},\"type\":\"stuck-at-0\",\"bit\":${bit},\"width\":${EXPECTED_WIDTH},\"signal\":\"${EXPECTED_SIGNAL}\"")
    set(sa1_record
        "{\"id\":${sa1_id},\"type\":\"stuck-at-1\",\"bit\":${bit},\"width\":${EXPECTED_WIDTH},\"signal\":\"${EXPECTED_SIGNAL}\"")

    foreach(record "${sa0_record}" "${sa1_record}")
        string(FIND "${compact}" "${record}" found_at)
        if(found_at EQUAL -1)
            message(FATAL_ERROR
                "faults.json is missing the expected record:\n  ${record}\nFull content:\n${faults_json_content}")
        endif()
    endforeach()
endforeach()

message(STATUS "Fault enumeration for ${DESIGN} matched: ${expected_count} faults, width ${EXPECTED_WIDTH}.")

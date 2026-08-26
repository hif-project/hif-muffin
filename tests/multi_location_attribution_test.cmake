# -----------------------------------------------------------------------------
# @brief  : Regression (#24): two fault locations on one signal must be
#           distinguishable by attribute.
# @details A fault record exists to be selected. hif-regression resolves every
#          fault by its attributes rather than by `id`, precisely because ids
#          are assigned in enumeration order and move whenever a design's
#          assignments change; its lookup requires a filter to match exactly one
#          record and treats an ambiguous filter as a fixture bug.
#
#          A signal driven by two continuous assignments to different
#          part-selects yields two genuinely different locations - they inject
#          into different halves of the vector - and both were reported with
#          `source: ""` and `line: 0`. That made eight pairs of records
#          identical in every field but `id`, so no filter could select either
#          one and a design in this shape could not be given a fixture at all.
#
#          The assertion is therefore the property the mechanism exists for, not
#          a spot check on one field: no two records in the report may be
#          identical once `id` is removed. That is what a caller needs, and it
#          would still fail if a future change made positions unique in name
#          only - by emitting the same wrong line for both, say.
#
#          Per-line counts are asserted as well, so the report cannot pass by
#          being distinct in some unintended way. The exact source basename is
#          required rather than merely a non-empty string, since an empty source
#          was half of the reported symptom.
#
#          Both forms of the design are run through this same script. The
#          procedural form was always attributed correctly and is the control: a
#          regression in the shared reporting path fails on both fixtures, which
#          distinguishes it from the frontend defect #24 actually was.
#
#          Stops at --list-faults. The subject is the report, so there is no
#          regeneration leg; hif2vhdl could not provide one anyway, since it
#          aborts on any part-select assignment target (hif-backend#103).
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

foreach(required
    MUFFIN_EXECUTABLE VERILOG2HIF_EXECUTABLE FIXTURE DESIGN WORK_DIR
    EXPECTED_SIGNAL EXPECTED_LINE_A EXPECTED_LINE_B EXPECTED_PER_LINE EXPECTED_TOTAL)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required variable: ${required}")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

get_filename_component(FIXTURE_NAME ${FIXTURE} NAME)

# --- Verilog -> HIF ------------------------------------------------------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -o ${DESIGN} ${FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE tool_output
    ERROR_VARIABLE tool_output
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif failed with exit code ${result}\n${tool_output}")
endif()

# --- Enumerate -----------------------------------------------------------

set(FAULTS_JSON ${WORK_DIR}/faults.json)
execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/${DESIGN}.hif.xml --list-faults ${FAULTS_JSON}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE tool_output
    ERROR_VARIABLE tool_output
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --list-faults failed with exit code ${result}\n${tool_output}")
endif()

file(READ ${FAULTS_JSON} faults_json_content)

# Collapse whitespace so records can be matched as compact substrings,
# independent of how the JSON writer happens to indent them.
string(REGEX REPLACE "[ \t\r\n]" "" compact "${faults_json_content}")

# --- The report has the shape this test assumes ---------------------------

string(REGEX MATCHALL "{\"id\":[0-9]+[^}]*}" records "${compact}")
list(LENGTH records record_count)
if(NOT record_count EQUAL ${EXPECTED_TOTAL})
    message(FATAL_ERROR
        "Expected ${EXPECTED_TOTAL} fault records but found ${record_count}. The design's location "
        "count has changed, so the per-line assertions below no longer mean what this test "
        "assumes.\nFull content:\n${faults_json_content}")
endif()

# --- No two records may be identical once `id` is removed ----------------

set(record_keys "")
foreach(record ${records})
    string(REGEX REPLACE "^{\"id\":[0-9]+," "{" record_key "${record}")
    list(APPEND record_keys "${record_key}")
endforeach()

set(unique_keys ${record_keys})
list(REMOVE_DUPLICATES unique_keys)
list(LENGTH record_keys key_count)
list(LENGTH unique_keys unique_count)

if(NOT key_count EQUAL unique_count)
    math(EXPR ambiguous "${key_count} - ${unique_count}")
    # Name them, so the failure says which locations collided rather than only
    # that some did.
    set(seen "")
    set(collisions "")
    # list(FIND) rather than IN_LIST: this script runs under `cmake -P`, which
    # does not inherit the project's policy settings, and IN_LIST needs CMP0057.
    foreach(record_key ${record_keys})
        list(FIND seen "${record_key}" seen_at)
        if(seen_at EQUAL -1)
            list(APPEND seen "${record_key}")
        else()
            list(APPEND collisions "${record_key}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES collisions)
    string(REPLACE ";" "\n  " collisions_text "${collisions}")
    message(FATAL_ERROR
        "${ambiguous} of ${key_count} fault records are identical to another record in every field "
        "but `id`, so neither can be selected by attribute (#24). Colliding keys:\n  "
        "${collisions_text}\nFull content:\n${faults_json_content}")
endif()

# --- Each location is attributed to its own source line ------------------

foreach(source_line ${EXPECTED_LINE_A} ${EXPECTED_LINE_B})
    string(REGEX MATCHALL
        "\"signal\":\"${EXPECTED_SIGNAL}\",\"source\":\"${FIXTURE_NAME}\",\"line\":${source_line}}"
        line_matches "${compact}")
    list(LENGTH line_matches line_count)
    if(NOT line_count EQUAL ${EXPECTED_PER_LINE})
        message(FATAL_ERROR
            "Expected ${EXPECTED_PER_LINE} records for signal '${EXPECTED_SIGNAL}' at "
            "${FIXTURE_NAME}:${source_line} but found ${line_count}. Before the fix for #24 the "
            "continuous-assign form reported every one of them with source \"\" and line 0 "
            "instead.\nFull content:\n${faults_json_content}")
    endif()
endforeach()

message(STATUS
    "multi_location_attribution (${DESIGN}): ${record_count} records, all distinguishable, "
    "${EXPECTED_PER_LINE} per line at ${FIXTURE_NAME}:${EXPECTED_LINE_A} and :${EXPECTED_LINE_B}.")

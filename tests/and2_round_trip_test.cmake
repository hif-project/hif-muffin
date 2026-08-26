# -----------------------------------------------------------------------------
# @brief  : End-to-end round-trip test: Verilog -> HIF -> muffin -> HIF ->
#           Verilog, run through the real verilog2hif/hif2verilog tools.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

include(${CMAKE_CURRENT_LIST_DIR}/hif_text_assert.cmake)

foreach(required MUFFIN_EXECUTABLE VERILOG2HIF_EXECUTABLE HIF2VERILOG_EXECUTABLE FIXTURE WORK_DIR)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required variable: ${required}")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

# --- Step 1: Verilog -> HIF ---------------------------------------------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -o and2 ${FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif failed with exit code ${result}")
endif()

set(HIF_FILE ${WORK_DIR}/and2.hif.xml)
if(NOT EXISTS ${HIF_FILE})
    message(FATAL_ERROR "Expected HIF file not produced: ${HIF_FILE}")
endif()

# --- Step 2: muffin --list-faults ---------------------------------------

set(FAULTS_JSON ${WORK_DIR}/faults.json)
execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${HIF_FILE} --list-faults ${FAULTS_JSON}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --list-faults failed with exit code ${result}")
endif()

file(READ ${FAULTS_JSON} faults_json_content)

foreach(expected
    "\"id\": 1"
    "\"type\": \"stuck-at-0\""
    "\"id\": 2"
    "\"type\": \"stuck-at-1\""
    "\"signal\": \"y\""
    "\"line\": 2"
    "\"source\": \"and2.v\""
)
    hif_assert_text_contains("${faults_json_content}" "${expected}" "faults.json")
endforeach()

# --- Step 3: muffin --instrument ----------------------------------------

set(INSTRUMENTED_HIF ${WORK_DIR}/and2_instrumented.hif.xml)
execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${HIF_FILE} --instrument -o ${INSTRUMENTED_HIF}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --instrument failed with exit code ${result}")
endif()

if(NOT EXISTS ${INSTRUMENTED_HIF})
    message(FATAL_ERROR "Expected instrumented HIF file not produced: ${INSTRUMENTED_HIF}")
endif()

# --- Step 4: instrumented HIF -> Verilog --------------------------------

execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} ${INSTRUMENTED_HIF} -D ${WORK_DIR}/verilog_out
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog failed with exit code ${result}")
endif()

set(OUTPUT_VERILOG ${WORK_DIR}/verilog_out/and2.v)
if(NOT EXISTS ${OUTPUT_VERILOG})
    message(FATAL_ERROR "Expected regenerated Verilog not produced: ${OUTPUT_VERILOG}")
endif()

file(READ ${OUTPUT_VERILOG} verilog_content)

foreach(expected
    "muffinMutPort"
    "muffinMutPort == 1"
    "muffinMutPort == 2"
    "a & b"
)
    hif_assert_text_contains("${verilog_content}" "${expected}" "Regenerated Verilog")
endforeach()

message(STATUS "and2 round-trip test passed.")

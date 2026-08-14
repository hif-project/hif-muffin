# -----------------------------------------------------------------------------
# @brief  : End-to-end behavioral test for bit-level fault injection on a
#           parameterized-width signal.
# @details Runs the full Verilog -> HIF -> muffin --instrument -> Verilog
#          pipeline on param_reg (WIDTH = 4), then simulates the result with
#          Icarus Verilog and checks that activating SA0/SA1 on bit N forces
#          exactly bit N and leaves the other three bits equal to the input.
#          This is the property that issue #9 broke: with the width mistaken
#          for 1, the injected value replaced the entire register.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

foreach(required
    MUFFIN_EXECUTABLE VERILOG2HIF_EXECUTABLE HIF2VERILOG_EXECUTABLE IVERILOG_EXECUTABLE VVP_EXECUTABLE
    FIXTURE TESTBENCH WORK_DIR)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required variable: ${required}")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

# --- Step 1: Verilog -> HIF ---------------------------------------------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -o param_reg ${FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif failed with exit code ${result}")
endif()

# --- Step 1b: baseline round trip, no Muffin -----------------------------
#
# Everything below assumes the toolchain can carry this fixture through
# HIF and back unchanged. Check that first, with Muffin entirely out of the
# pipeline, so a frontend/backend defect is reported as one instead of being
# mistaken for an instrumentation bug.

execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} param_reg.hif.xml -D baseline
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog (baseline, no Muffin) failed with exit code ${result}")
endif()

file(READ ${WORK_DIR}/baseline/param_reg.v baseline_content)
foreach(preserved "parameter WIDTH = 4" "[WIDTH - 1:0]")
    string(FIND "${baseline_content}" "${preserved}" found_at)
    if(found_at EQUAL -1)
        message(FATAL_ERROR
            "PRECONDITION FAILED: a plain verilog2hif -> hif2verilog round trip of this fixture, with no "
            "Muffin involved, already loses '${preserved}'. This is an upstream toolchain defect, not a "
            "fault-injection one.\n--- baseline (no Muffin) ---\n${baseline_content}")
    endif()
endforeach()

# --- Step 2: instrument --------------------------------------------------

execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/param_reg.hif.xml --instrument -o ${WORK_DIR}/param_reg_i.hif.xml
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --instrument failed with exit code ${result}")
endif()

# --- Step 3: instrumented HIF -> Verilog --------------------------------

# Run from inside the work directory: hif2verilog also drops
# HIF2VERILOG_01_Final_tree.hif* debug files into the current directory.
execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} param_reg_i.hif.xml -D generated
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog failed with exit code ${result}")
endif()

set(GENERATED ${WORK_DIR}/generated/param_reg.v)
if(NOT EXISTS ${GENERATED})
    message(FATAL_ERROR "Expected regenerated Verilog not produced: ${GENERATED}")
endif()

# The injected masks must be 4-bit literals, not whole-register replacements.
# Checked here as well as behaviorally so a failure points straight at the
# injector rather than only at a simulation mismatch.
file(READ ${GENERATED} generated_content)
foreach(expected "4'b1110" "4'b0001" "4'b0111" "4'b1000")
    string(FIND "${generated_content}" "${expected}" found_at)
    if(found_at EQUAL -1)
        message(FATAL_ERROR
            "Regenerated Verilog is missing the bit-mask literal ${expected}; the injector is not forcing a "
            "single bit.\nFull content:\n${generated_content}")
    endif()
endforeach()

# Resolving the width must not consume the parameter. Muffin folds WIDTH only
# to answer "how many bits is this?"; if that simplification runs in place it
# substitutes the parameter into the tree and deletes the declaration, and the
# module regenerates without its `parameter WIDTH = 4` header and with a span
# of [18446744073709551615:0]. The design must come out as it went in.
foreach(preserved "parameter WIDTH = 4" "[WIDTH - 1:0]")
    string(FIND "${generated_content}" "${preserved}" found_at)
    if(found_at EQUAL -1)
        message(FATAL_ERROR
            "Regenerated Verilog no longer contains '${preserved}'. Resolving the location's width has "
            "mutated the design instead of only querying it.\nFull content:\n${generated_content}")
    endif()
endforeach()

# --- Step 4: compile and simulate ---------------------------------------

execute_process(
    COMMAND ${IVERILOG_EXECUTABLE} -o ${WORK_DIR}/sim ${GENERATED} ${TESTBENCH}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "iverilog failed with exit code ${result}")
endif()

execute_process(
    COMMAND ${VVP_EXECUTABLE} ${WORK_DIR}/sim
    RESULT_VARIABLE result
    OUTPUT_VARIABLE sim_output
    ERROR_VARIABLE sim_error
)

if(NOT result EQUAL 0)
    message(FATAL_ERROR
        "Simulation failed with exit code ${result}.\n${sim_output}\n${sim_error}\n"
        "--- generated Verilog under test ---\n${generated_content}")
endif()

string(FIND "${sim_output}" "RESULT: PASS" found_at)
if(found_at EQUAL -1)
    message(FATAL_ERROR
        "Simulation did not report a passing result.\n${sim_output}\n${sim_error}\n"
        "--- generated Verilog under test ---\n${generated_content}")
endif()

message(STATUS "param_reg behavioral test passed.")

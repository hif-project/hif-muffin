# -----------------------------------------------------------------------------
# @brief  : End-to-end behavioral test for hierarchical fault injection.
# @details Runs the full `verilog2hif -s` -> muffin --instrument ->
#          hif2verilog pipeline on hier_adder/half_adder, then compiles and
#          simulates the regenerated hierarchy and checks golden behaviour plus
#          four selected faults against exact oracles.
#
#          This is the simulation half that issue #10 asked for and that
#          hierarchical_wiring could not provide. Until
#          hif-project/hif-backend#26 was fixed the regenerated parent declared
#          its instance-connected nets as `reg`, which Verilog forbids as the
#          target of an instance output, so the design was rejected at
#          elaboration and hierarchical instrumentation could only be checked
#          structurally. `.ci/pinned-refs.env` pins the backend commit that
#          carries the fix.
#
#          Kept separate from hierarchical_wiring on purpose: that test pins
#          *where* the activation port is wired, including the flattened flow
#          where nothing is wired at all, and must keep running on toolchains
#          without a simulator. This one pins what the wiring *does*.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

foreach(required
    MUFFIN_EXECUTABLE VERILOG2HIF_EXECUTABLE HIF2VERILOG_EXECUTABLE IVERILOG_EXECUTABLE VVP_EXECUTABLE
    PARENT_FIXTURE CHILD_FIXTURE TESTBENCH WORK_DIR)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required variable: ${required}")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

# --- Step 1: Verilog -> HIF, hierarchy preserved -------------------------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -s -o hier ${PARENT_FIXTURE} ${CHILD_FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif -s failed with exit code ${result}")
endif()

# --- Step 1b: baseline round trip, no Muffin -----------------------------
#
# Everything below assumes the toolchain can carry a preserved hierarchy
# through HIF and back into something a simulator accepts. Check that with
# Muffin out of the pipeline first, so an upstream round-trip defect is
# reported as one instead of being mistaken for an instrumentation bug. This
# is exactly the step that failed before hif-project/hif-backend#26.

execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} hier.hif.xml -D baseline
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog (baseline, no Muffin) failed with exit code ${result}")
endif()

execute_process(
    COMMAND ${IVERILOG_EXECUTABLE} -g2005 -o ${WORK_DIR}/baseline_sim
            ${WORK_DIR}/baseline/half_adder.v ${WORK_DIR}/baseline/hier_adder.v
    RESULT_VARIABLE result
    OUTPUT_VARIABLE baseline_compile_output
    ERROR_VARIABLE baseline_compile_output
)
if(NOT result EQUAL 0)
    file(READ ${WORK_DIR}/baseline/hier_adder.v baseline_parent)
    message(FATAL_ERROR
        "PRECONDITION FAILED: a plain `verilog2hif -s` -> hif2verilog round trip of these fixtures, with no "
        "Muffin involved, does not compile. This is an upstream toolchain defect, not a fault-injection one "
        "(hif-project/hif-backend#26 was this).\n${baseline_compile_output}\n"
        "--- baseline parent (no Muffin) ---\n${baseline_parent}")
endif()

# --- Step 2: instrument --------------------------------------------------

execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/hier.hif.xml --instrument -o ${WORK_DIR}/hier_i.hif.xml
    RESULT_VARIABLE result
    OUTPUT_VARIABLE instrument_output
    ERROR_VARIABLE instrument_error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --instrument failed with exit code ${result}\n${instrument_output}\n${instrument_error}")
endif()

# The oracles in the testbench are written against the enumeration this
# design produces: faults 1-4 in the child, 5-6 on the parent's own cout. If
# enumeration changes, the expectations below become wrong rather than
# failing usefully, so pin the ids to their signals here.
execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/hier.hif.xml --list-faults ${WORK_DIR}/faults.json
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --list-faults failed with exit code ${result}")
endif()

file(READ ${WORK_DIR}/faults.json faults_content)
# id -> (signal, type) pairs the testbench relies on.
set(expected_faults
    "1:sum:stuck-at-0"
    "3:carry:stuck-at-0"
    "5:cout:stuck-at-0"
    "6:cout:stuck-at-1"
)
foreach(expected_fault ${expected_faults})
    string(REPLACE ":" ";" fault_parts ${expected_fault})
    list(GET fault_parts 0 fault_id)
    list(GET fault_parts 1 fault_signal)
    list(GET fault_parts 2 fault_type)
    if(NOT faults_content MATCHES
       "\"id\"[ \t]*:[ \t]*${fault_id},[^{]*\"type\"[ \t]*:[ \t]*\"${fault_type}\"[^{]*\"signal\"[ \t]*:[ \t]*\"${fault_signal}\"")
        message(FATAL_ERROR
            "Fault ${fault_id} is not ${fault_type} on '${fault_signal}'. The testbench's oracles are written "
            "against that enumeration, so they would now be checking the wrong fault.\n${faults_content}")
    endif()
endforeach()

# --- Step 3: instrumented HIF -> Verilog --------------------------------

# Run from inside the work directory: hif2verilog also drops
# HIF2VERILOG_01_Final_tree.hif* debug files into the current directory.
execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} hier_i.hif.xml -D generated
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog failed with exit code ${result}")
endif()

set(GENERATED_PARENT ${WORK_DIR}/generated/hier_adder.v)
set(GENERATED_CHILD ${WORK_DIR}/generated/half_adder.v)
foreach(expected ${GENERATED_PARENT} ${GENERATED_CHILD})
    if(NOT EXISTS ${expected})
        message(FATAL_ERROR "Expected regenerated Verilog not produced: ${expected}")
    endif()
endforeach()

file(READ ${GENERATED_PARENT} generated_parent_content)

# The hierarchy must still be there. A flattened parent would simulate
# correctly and prove nothing about hierarchical instrumentation.
if(NOT generated_parent_content MATCHES "half_adder[ \t\n]+u_ha1")
    message(FATAL_ERROR
        "Regenerated parent does not instantiate the child; there is no hierarchy left to test.\n"
        "${generated_parent_content}")
endif()

# --- Step 4: compile and simulate ---------------------------------------

execute_process(
    COMMAND ${IVERILOG_EXECUTABLE} -g2005 -o ${WORK_DIR}/sim
            ${GENERATED_CHILD} ${GENERATED_PARENT} ${TESTBENCH}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE compile_output
    ERROR_VARIABLE compile_output
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR
        "iverilog failed with exit code ${result}.\n${compile_output}\n"
        "--- generated parent under test ---\n${generated_parent_content}")
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
        "--- generated parent under test ---\n${generated_parent_content}")
endif()

string(FIND "${sim_output}" "RESULT: PASS" found_at)
if(found_at EQUAL -1)
    message(FATAL_ERROR
        "Simulation did not report a passing result.\n${sim_output}\n${sim_error}\n"
        "--- generated parent under test ---\n${generated_parent_content}")
endif()

message(STATUS "Hierarchical behavioral test passed.")

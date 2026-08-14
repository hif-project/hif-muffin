# -----------------------------------------------------------------------------
# @brief  : Covers MutPortInjector::visitInstance -- the per-instance
#           activation-port wiring that carries muffinMutPort down a hierarchy.
# @details Issue #10 observed that this code never runs in the *default*
#          verilog2hif flow, and asked whether it is dead. It is not: the
#          frontend's flattening is opt-out via `-s`/`--structure`, and with
#          that flag the instances survive into HIF and the wiring runs. This
#          test pins both halves of that behavior so neither can regress
#          silently:
#
#            - without `-s`: the design arrives flat, and Muffin reports zero
#              instances wired (this is correct, not a failure);
#            - with `-s`: the instances survive, Muffin wires the port through
#              every view and every instance, and the regenerated Verilog binds
#              muffinMutPort on each instantiation.
#
#          Deliberately asserts on structure rather than simulating: the `-s`
#          round trip currently regenerates internal connection nets as `reg`,
#          which Verilog forbids as the target of an instance output port. That
#          reproduces with no Muffin in the pipeline at all, so it is an
#          upstream backend limitation and not this repo's to assert against.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

foreach(required
    MUFFIN_EXECUTABLE VERILOG2HIF_EXECUTABLE HIF2VERILOG_EXECUTABLE PARENT_FIXTURE CHILD_FIXTURE WORK_DIR)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required variable: ${required}")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

# --- Case 1: default flow, hierarchy is flattened by the frontend --------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -o flat ${PARENT_FIXTURE} ${CHILD_FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif (default) failed with exit code ${result}")
endif()

execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/flat.hif.xml --instrument -o ${WORK_DIR}/flat_i.hif.xml
    RESULT_VARIABLE result
    OUTPUT_VARIABLE flat_output
    ERROR_VARIABLE flat_error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --instrument (flat) failed with exit code ${result}\n${flat_output}\n${flat_error}")
endif()

set(flat_log "${flat_output}${flat_error}")
if(NOT flat_log MATCHES "and 0 instance\\(s\\)")
    message(FATAL_ERROR
        "Expected the default (flattened) flow to wire 0 instances. If the frontend has stopped inlining by "
        "default, this test's premise -- and the note in README.md -- need revisiting.\n${flat_log}")
endif()

# --- Case 2: -s preserves the hierarchy, so visitInstance runs -----------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -s -o hier ${PARENT_FIXTURE} ${CHILD_FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif -s failed with exit code ${result}")
endif()

# Precondition: the instances really did survive the frontend. Without this a
# regression in verilog2hif would make the assertions below vacuous rather
# than failing.
file(READ ${WORK_DIR}/hier.hif.xml hier_hif_content)
string(REGEX MATCHALL "<INSTANCE" instance_matches "${hier_hif_content}")
list(LENGTH instance_matches instance_count)
if(instance_count LESS 2)
    message(FATAL_ERROR
        "verilog2hif -s produced ${instance_count} Instance node(s); expected at least 2, so this test would "
        "not be exercising per-instance wiring at all.")
endif()

execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/hier.hif.xml --instrument -o ${WORK_DIR}/hier_i.hif.xml
    RESULT_VARIABLE result
    OUTPUT_VARIABLE hier_output
    ERROR_VARIABLE hier_error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --instrument (-s) failed with exit code ${result}\n${hier_output}\n${hier_error}")
endif()

set(hier_log "${hier_output}${hier_error}")

# Two RTL views (hier_adder, half_adder) and two instances (u_ha1, u_ha2).
if(NOT hier_log MATCHES "through 2 view\\(s\\) and 2 instance\\(s\\)")
    message(FATAL_ERROR
        "Expected muffin to wire the activation port through 2 views and 2 instances.\n${hier_log}")
endif()

# The wiring must be in the tree, not merely counted.
file(READ ${WORK_DIR}/hier_i.hif.xml instrumented_content)
string(REGEX MATCHALL "PORTASSIGN[^>]*name=\"muffinMutPort\"" portassign_matches "${instrumented_content}")
list(LENGTH portassign_matches portassign_count)
if(portassign_count LESS 2)
    message(FATAL_ERROR
        "Instrumented HIF carries ${portassign_count} muffinMutPort port assign(s); expected one per instance.")
endif()

# --- Case 2b: the wiring survives regeneration to Verilog ---------------

execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} hier_i.hif.xml -D generated
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog failed with exit code ${result}")
endif()

set(GENERATED_PARENT ${WORK_DIR}/generated/hier_adder.v)
if(NOT EXISTS ${GENERATED_PARENT})
    message(FATAL_ERROR "Expected regenerated parent module not produced: ${GENERATED_PARENT}")
endif()

file(READ ${GENERATED_PARENT} generated_parent_content)

# Both instantiations must bind the activation port to the parent's own port,
# which is what makes a single top-level value reach every level.
string(REGEX MATCHALL "\\.muffinMutPort\\(muffinMutPort\\)" binding_matches "${generated_parent_content}")
list(LENGTH binding_matches binding_count)
if(binding_count LESS 2)
    message(FATAL_ERROR
        "Regenerated parent binds muffinMutPort on ${binding_count} instance(s); expected 2.\n"
        "${generated_parent_content}")
endif()

# The child must still be a separate module carrying its own faults, rather
# than having been inlined after all.
set(GENERATED_CHILD ${WORK_DIR}/generated/half_adder.v)
if(NOT EXISTS ${GENERATED_CHILD})
    message(FATAL_ERROR "Expected regenerated child module not produced: ${GENERATED_CHILD}")
endif()

file(READ ${GENERATED_CHILD} generated_child_content)
foreach(expected "muffinMutPort" "muffinMutPort == 1")
    string(FIND "${generated_child_content}" "${expected}" found_at)
    if(found_at EQUAL -1)
        message(FATAL_ERROR
            "Regenerated child module is missing expected content: ${expected}\n${generated_child_content}")
    endif()
endforeach()

message(STATUS "Hierarchical activation-port wiring test passed.")

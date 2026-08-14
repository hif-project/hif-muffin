# -----------------------------------------------------------------------------
# @brief  : Checks that changing muffinMutPort alone re-evaluates instrumented
#           combinational logic, and that clocked processes are left alone.
# @details Issue #16: instrumenting adds a read of muffinMutPort to a process
#          without adding it to that process's sensitivity list, so on a
#          settled combinational design the fault does not take effect until
#          some unrelated input toggles.
#
#          Two halves, deliberately opposite:
#            - and2 (combinational) must gain the port in its sensitivity list
#              and satisfy the activate/clear contract in simulation;
#            - param_reg (clocked) must NOT gain it, since a register has no
#              business updating between clock edges because the activation
#              port moved.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

foreach(required
    MUFFIN_EXECUTABLE VERILOG2HIF_EXECUTABLE HIF2VERILOG_EXECUTABLE IVERILOG_EXECUTABLE VVP_EXECUTABLE
    COMB_FIXTURE COMB_TESTBENCH SEQ_FIXTURE WORK_DIR)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "Missing required variable: ${required}")
    endif()
endforeach()

file(REMOVE_RECURSE ${WORK_DIR})
file(MAKE_DIRECTORY ${WORK_DIR})

# --- Combinational: must become sensitive to the activation port ---------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -o and2 ${COMB_FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif failed with exit code ${result}")
endif()

execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/and2.hif.xml --instrument -o ${WORK_DIR}/and2_i.hif.xml
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --instrument failed with exit code ${result}")
endif()

execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} and2_i.hif.xml -D generated
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog failed with exit code ${result}")
endif()

set(GENERATED_COMB ${WORK_DIR}/generated/and2.v)
file(READ ${GENERATED_COMB} comb_content)

# Checked structurally as well as behaviorally so a failure says whether the
# sensitivity list is wrong or the simulation disagrees for some other reason.
if(NOT comb_content MATCHES "always[ \t]*@\\([^)]*muffinMutPort[^)]*\\)")
    message(FATAL_ERROR
        "The instrumented combinational process is not sensitive to muffinMutPort, so changing the "
        "activation port alone cannot re-evaluate it.\n${comb_content}")
endif()

execute_process(
    COMMAND ${IVERILOG_EXECUTABLE} -o ${WORK_DIR}/sim ${GENERATED_COMB} ${COMB_TESTBENCH}
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
        "--- generated Verilog under test ---\n${comb_content}")
endif()

string(FIND "${sim_output}" "RESULT: PASS" found_at)
if(found_at EQUAL -1)
    message(FATAL_ERROR
        "muffinMutPort alone did not activate and clear the fault.\n${sim_output}\n${sim_error}\n"
        "--- generated Verilog under test ---\n${comb_content}")
endif()

# --- Clocked: must be left exactly as it was -----------------------------

execute_process(
    COMMAND ${VERILOG2HIF_EXECUTABLE} -o param_reg ${SEQ_FIXTURE}
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "verilog2hif (sequential) failed with exit code ${result}")
endif()

execute_process(
    COMMAND ${MUFFIN_EXECUTABLE} ${WORK_DIR}/param_reg.hif.xml --instrument -o ${WORK_DIR}/param_reg_i.hif.xml
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "muffin --instrument (sequential) failed with exit code ${result}")
endif()

execute_process(
    COMMAND ${HIF2VERILOG_EXECUTABLE} param_reg_i.hif.xml -D generated_seq
    WORKING_DIRECTORY ${WORK_DIR}
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "hif2verilog (sequential) failed with exit code ${result}")
endif()

file(READ ${WORK_DIR}/generated_seq/param_reg.v seq_content)

if(seq_content MATCHES "always[ \t]*@\\([^)]*muffinMutPort[^)]*\\)")
    message(FATAL_ERROR
        "A clocked process gained muffinMutPort in its sensitivity list. A register must not update "
        "between clock edges because the activation port changed.\n${seq_content}")
endif()

if(NOT seq_content MATCHES "always[ \t]*@\\([ \t]*posedge[ \t]+clk[ \t]*\\)")
    message(FATAL_ERROR
        "The clocked process no longer waits on posedge clk alone.\n${seq_content}")
endif()

message(STATUS "muffinMutPort sensitivity test passed.")

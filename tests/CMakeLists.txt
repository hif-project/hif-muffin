# -----------------------------------------------------------------------------
# @brief  : Tests cmake file.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

# The full round-trip test needs the real verilog2hif/hif2verilog tools, which
# live in the sibling hif-frontend/hif-backend repos rather than as a build
# dependency of this one. Look for them on PATH and, since this project is
# normally checked out alongside its siblings, in their build directories too.
find_program(
    VERILOG2HIF_EXECUTABLE
    NAMES verilog2hif
    HINTS ${CMAKE_SOURCE_DIR}/../hif-frontend/build
)
find_program(
    HIF2VERILOG_EXECUTABLE
    NAMES hif2verilog
    HINTS ${CMAKE_SOURCE_DIR}/../hif-backend/build
)

# Only the behavioral test needs a simulator.
find_program(IVERILOG_EXECUTABLE NAMES iverilog)
find_program(VVP_EXECUTABLE NAMES vvp)

if(VERILOG2HIF_EXECUTABLE AND HIF2VERILOG_EXECUTABLE)
    add_test(
        NAME and2_round_trip
        COMMAND ${CMAKE_COMMAND}
            -DMUFFIN_EXECUTABLE=$<TARGET_FILE:muffin>
            -DVERILOG2HIF_EXECUTABLE=${VERILOG2HIF_EXECUTABLE}
            -DHIF2VERILOG_EXECUTABLE=${HIF2VERILOG_EXECUTABLE}
            -DFIXTURE=${CMAKE_CURRENT_SOURCE_DIR}/fixtures/and2.v
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/and2_round_trip
            -P ${CMAKE_CURRENT_SOURCE_DIR}/and2_round_trip_test.cmake
    )
    # Per-instance activation-port wiring (issue #10). Kept separate from the
    # flat round trip because it deliberately drives verilog2hif both ways:
    # default (inlined) and -s (hierarchy preserved).
    add_test(
        NAME hierarchical_wiring
        COMMAND ${CMAKE_COMMAND}
            -DMUFFIN_EXECUTABLE=$<TARGET_FILE:muffin>
            -DVERILOG2HIF_EXECUTABLE=${VERILOG2HIF_EXECUTABLE}
            -DHIF2VERILOG_EXECUTABLE=${HIF2VERILOG_EXECUTABLE}
            -DPARENT_FIXTURE=${CMAKE_CURRENT_SOURCE_DIR}/fixtures/hier_adder.v
            -DCHILD_FIXTURE=${CMAKE_CURRENT_SOURCE_DIR}/fixtures/half_adder.v
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/hierarchical_wiring
            -P ${CMAKE_CURRENT_SOURCE_DIR}/hierarchical_wiring_test.cmake
    )
else()
    message(STATUS "verilog2hif/hif2verilog not found; skipping and2_round_trip and hierarchical_wiring tests.")
endif()

# Fault enumeration across the three width classes. The two register fixtures
# are deliberately the same design written twice, once with a literal span and
# once with a parameterized one, so any difference between them is the bug from
# issue #9 and nothing else.
if(VERILOG2HIF_EXECUTABLE)
    # design            fixture           signal  width
    set(enumeration_cases
        "and2:and2.v:y:1"
        "fixed_reg:fixed_reg.v:q:4"
        "param_reg:param_reg.v:q:4"
        "param_counter:param_counter.v:count:4"
    )

    foreach(enumeration_case ${enumeration_cases})
        string(REPLACE ":" ";" case_parts ${enumeration_case})
        list(GET case_parts 0 case_design)
        list(GET case_parts 1 case_fixture)
        list(GET case_parts 2 case_signal)
        list(GET case_parts 3 case_width)

        add_test(
            NAME fault_enumeration_${case_design}
            COMMAND ${CMAKE_COMMAND}
                -DMUFFIN_EXECUTABLE=$<TARGET_FILE:muffin>
                -DVERILOG2HIF_EXECUTABLE=${VERILOG2HIF_EXECUTABLE}
                -DFIXTURE=${CMAKE_CURRENT_SOURCE_DIR}/fixtures/${case_fixture}
                -DDESIGN=${case_design}
                -DEXPECTED_SIGNAL=${case_signal}
                -DEXPECTED_WIDTH=${case_width}
                -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/fault_enumeration_${case_design}
                -P ${CMAKE_CURRENT_SOURCE_DIR}/fault_enumeration_test.cmake
        )
    endforeach()
else()
    message(STATUS "verilog2hif not found; skipping fault_enumeration tests.")
endif()

# Behavioral proof that a fault on bit N forces bit N and only bit N.
if(VERILOG2HIF_EXECUTABLE AND HIF2VERILOG_EXECUTABLE AND IVERILOG_EXECUTABLE AND VVP_EXECUTABLE)
    add_test(
        NAME param_reg_behavioral
        COMMAND ${CMAKE_COMMAND}
            -DMUFFIN_EXECUTABLE=$<TARGET_FILE:muffin>
            -DVERILOG2HIF_EXECUTABLE=${VERILOG2HIF_EXECUTABLE}
            -DHIF2VERILOG_EXECUTABLE=${HIF2VERILOG_EXECUTABLE}
            -DIVERILOG_EXECUTABLE=${IVERILOG_EXECUTABLE}
            -DVVP_EXECUTABLE=${VVP_EXECUTABLE}
            -DFIXTURE=${CMAKE_CURRENT_SOURCE_DIR}/fixtures/param_reg.v
            -DTESTBENCH=${CMAKE_CURRENT_SOURCE_DIR}/fixtures/param_reg_tb.v
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/param_reg_behavioral
            -P ${CMAKE_CURRENT_SOURCE_DIR}/param_reg_behavioral_test.cmake
    )
else()
    message(STATUS "verilog2hif/hif2verilog/iverilog not found; skipping param_reg_behavioral test.")
endif()

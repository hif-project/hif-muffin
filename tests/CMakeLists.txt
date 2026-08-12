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
else()
    message(STATUS "verilog2hif/hif2verilog not found; skipping and2_round_trip test.")
endif()

# -----------------------------------------------------------------------------
# @brief  : HIF cmake file.
# @author : Enrico Fraccaroli
# -----------------------------------------------------------------------------

# Set the minimum CMake version, the project name and default build type.
cmake_minimum_required(VERSION 3.1...3.18)

# Set the project name.
project(muffin CXX)

# Set the default build type to Debug.
if(NOT CMAKE_BUILD_TYPE)
    message(STATUS "Setting build type to 'Debug' as none was specified.")
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Choose the type of build." FORCE)
endif()

# Set the install prefix.
set(CMAKE_INSTALL_PREFIX /usr/local)

# Set modules path.
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PROJECT_SOURCE_DIR}/cmake)

# -----------------------------------------------------------------------------
# OPTIONS
# -----------------------------------------------------------------------------

option(STRICT_WARNINGS "Enable strict compiler warnings" ON)
option(WARNINGS_AS_ERRORS "Treat all warnings as errors" OFF)

# -----------------------------------------------------------------------------
# ENABLE FETCH CONTENT
# -----------------------------------------------------------------------------

# We need this in order to import external projects.
include(FetchContent)
# Hide fetchcontent variables.
mark_as_advanced(FORCE
    FETCHCONTENT_QUIET
    FETCHCONTENT_BASE_DIR
    FETCHCONTENT_FULLY_DISCONNECTED
    FETCHCONTENT_UPDATES_DISCONNECTED
)

# -----------------------------------------------------------------------------
# DEPENDENCY (SYSTEM LIBRARIES)
# -----------------------------------------------------------------------------

find_package(Doxygen)
find_package(HIF REQUIRED)
find_program(CLANG_TIDY_EXE NAMES clang-tidy)

# -----------------------------------------------------------------------------
# DEPENDENCY (FETCHCONTENT LIBRARIES)
# -----------------------------------------------------------------------------

# Don't build json's own examples/tests as part of our build.
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    json
    GIT_REPOSITORY "https://github.com/Galfurian/json.git"
    GIT_SHALLOW    TRUE
    GIT_PROGRESS   TRUE
    GIT_TAG        main
)
FetchContent_GetProperties(json)
if(NOT json_POPULATED)
    message(STATUS "Retrieving `json`...")
    FetchContent_MakeAvailable(json)
    # Hide fetchcontent variables.
    mark_as_advanced(FORCE FETCHCONTENT_UPDATES_DISCONNECTED_JSON FETCHCONTENT_SOURCE_DIR_JSON)
endif()

# -----------------------------------------------------------------------------
# EXECUTABLE: muffin
# -----------------------------------------------------------------------------

# Create the executable.
add_executable(
    muffin
    ${CMAKE_SOURCE_DIR}/src/muffin/main.cpp
    ${CMAKE_SOURCE_DIR}/src/muffin/MuffinParseLine.cpp
    ${CMAKE_SOURCE_DIR}/src/muffin/discovery/LocationVisitor.cpp
    ${CMAKE_SOURCE_DIR}/src/muffin/faults/FaultEnumerator.cpp
    ${CMAKE_SOURCE_DIR}/src/muffin/injection/MutPortInjector.cpp
    ${CMAKE_SOURCE_DIR}/src/muffin/injection/Instrumenter.cpp
    ${CMAKE_SOURCE_DIR}/src/muffin/report/FaultReportWriter.cpp
)
# Include directories.
target_include_directories(muffin PRIVATE ${CMAKE_SOURCE_DIR}/include ${HIF_INCLUDE_DIR})
# Link libraries.
target_link_libraries(muffin PRIVATE ${HIF_LIBRARY} json::json)
# Compilation options.
if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    # Disable warnings for MSVC-specific "safe" functions like strcpy_s, etc.,
    # which are not portable and may clutter warning logs.
    target_compile_definitions(muffin PRIVATE _CRT_SECURE_NO_WARNINGS)
    # Disable warning C4702: unreachable code.
    add_compile_options(/wd4702)
    if(WARNINGS_AS_ERRORS)
        # Treat all warnings as errors to enforce stricter code quality.
        target_compile_options(muffin PRIVATE /WX)
    endif()
    if(STRICT_WARNINGS)
        # Enable external header management to suppress warnings in system and
        # external headers, making it easier to focus on project-specific issues.
        target_compile_options(muffin PRIVATE /experimental:external)
        target_compile_options(muffin PRIVATE /external:I ${CMAKE_BINARY_DIR})
        target_compile_options(muffin PRIVATE /external:anglebrackets)
        target_compile_options(muffin PRIVATE /external:W0)

        # Use a high warning level to catch as many potential issues as possible.
        target_compile_options(muffin PRIVATE /W4)

        # Enforce standards-compliant behavior to avoid relying on MSVC-specific extensions.
        target_compile_options(muffin PRIVATE /permissive-)
    endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    if(WARNINGS_AS_ERRORS)
        # Treat all warnings as errors to enforce stricter code quality.
        target_compile_options(muffin PRIVATE -Werror)
    endif()
    if(STRICT_WARNINGS)
        # Enable a broad set of warnings to catch common and subtle issues:
        target_compile_options(muffin PRIVATE
            -Wall                # Enable most general-purpose warnings.
            -Wextra              # Enable extra warnings not included in -Wall.
            -Wconversion         # Warn about implicit type conversions that may lose data.
            -pedantic            # Enforce strict compliance with the C++ standard.
            -Wshadow             # Warn about variable shadowing, which can cause subtle bugs.
            -Wnon-virtual-dtor   # Warn when a class with virtual functions lacks a virtual destructor.
            -Wnull-dereference   # Warn about potential null pointer dereferences.
            -Wformat=2           # Enable strict checks for printf/scanf format strings.
            -Woverloaded-virtual # Warn when a derived class function hides a base class virtual function.
            -Wfloat-equal        # Warn about direct comparisons of floating-point values, which can be imprecise.
        )
    endif()
endif()
# Install the executable.
install(TARGETS muffin DESTINATION bin)

# -----------------------------------------------------------------------------
# CODE ANALYSIS
# -----------------------------------------------------------------------------

if(CLANG_TIDY_EXE)
    file(GLOB_RECURSE ALL_PROJECT_FILES
        "${PROJECT_SOURCE_DIR}/include/**/*.hpp"
        "${PROJECT_SOURCE_DIR}/include/*.hpp"
        "${PROJECT_SOURCE_DIR}/src/**/*.cpp"
        "${PROJECT_SOURCE_DIR}/src/*.cpp"
    )
    add_custom_target(
        ${PROJECT_NAME}_clang_tidy
        COMMAND ${CLANG_TIDY_EXE}
        --p=${CMAKE_BINARY_DIR}
        ${ALL_PROJECT_FILES}
        COMMENT "Running clang-tidy"
        VERBATIM
    )
    add_custom_target(
        ${PROJECT_NAME}_clang_tidy_fix
        COMMAND ${CLANG_TIDY_EXE}
        --fix --fix-errors
        --p=${CMAKE_BINARY_DIR}
        ${ALL_PROJECT_FILES}
        COMMENT "Running clang-tidy-fix"
        VERBATIM
    )
endif()

# -----------------------------------------------------------------------------
# DOCUMENTATION
# -----------------------------------------------------------------------------

if(DOXYGEN_FOUND)

    # FetchContent: Doxygen Awesome CSS
    FetchContent_Declare(doxygenawesome
        GIT_REPOSITORY https://github.com/jothepro/doxygen-awesome-css
        GIT_TAG main
    )
    FetchContent_MakeAvailable(doxygenawesome)

    # Hide FetchContent variables to avoid clutter in ccmake.
    mark_as_advanced(FORCE
        FETCHCONTENT_UPDATES_DISCONNECTED_DOXYGENAWESOME
        FETCHCONTENT_SOURCE_DIR_DOXYGENAWESOME
    )

    # Customization: Doxygen Configuration
    set(DOXYGEN_WARN_FORMAT "$file:$line:1: $text")
    set(DOXYGEN_PROJECT_NAME "HIF Muffin")
    set(DOXYGEN_PROJECT_BRIEF "Automatic fault injection for RTL designs, built on HIF.")
    set(DOXYGEN_USE_MDFILE_AS_MAINPAGE ${PROJECT_SOURCE_DIR}/README.md)
    set(DOXYGEN_SHOW_INCLUDE_FILES NO)
    set(DOXYGEN_GENERATE_TREEVIEW YES)
    set(DOXYGEN_GENERATE_LATEX NO) # Disable LaTeX if not needed
    set(DOXYGEN_GENERATE_MAN NO)   # Disable man pages if not needed

    # Styling and UX enhancements using Doxygen Awesome
    set(DOXYGEN_HTML_HEADER ${doxygenawesome_SOURCE_DIR}/doxygen-custom/header.html)
    set(DOXYGEN_HTML_EXTRA_STYLESHEET ${doxygenawesome_SOURCE_DIR}/doxygen-awesome.css)
    set(DOXYGEN_HTML_EXTRA_FILES
        ${doxygenawesome_SOURCE_DIR}/doxygen-awesome-fragment-copy-button.js
        ${doxygenawesome_SOURCE_DIR}/doxygen-awesome-paragraph-link.js
        ${doxygenawesome_SOURCE_DIR}/doxygen-awesome-darkmode-toggle.js
    )

    # Set stricter warnings for better documentation quality
    set(DOXYGEN_WARN_IF_UNDOCUMENTED YES)
    set(DOXYGEN_WARN_IF_DOC_ERROR YES)
    set(DOXYGEN_WARN_NO_PARAMDOC YES)
    set(DOXYGEN_WARN_AS_ERROR NO) # Treat warnings as errors for CI

    # Add Doxygen documentation target.
    file(GLOB_RECURSE ALL_PROJECT_FILES
        "${PROJECT_SOURCE_DIR}/include/**/*.hpp"
        "${PROJECT_SOURCE_DIR}/include/*.hpp"
        "${PROJECT_SOURCE_DIR}/src/**/*.cpp"
        "${PROJECT_SOURCE_DIR}/src/*.cpp"
    )

    doxygen_add_docs(
        ${PROJECT_NAME}_documentation
        ${PROJECT_SOURCE_DIR}/README.md
        ${PROJECT_SOURCE_DIR}/LICENSE.md
        ${ALL_PROJECT_FILES}
        COMMENT "Generating Doxygen documentation for the library"
    )

endif()

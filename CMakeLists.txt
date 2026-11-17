set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
cmake_minimum_required(VERSION 3.25)

set(REPO_NAME IntegrationTests)
set(REPO_OPTION_PREFIX OPENDAQ_INTEGRATION_TESTS)

list(APPEND CMAKE_MESSAGE_CONTEXT ${REPO_NAME})
add_subdirectory(cmake)

set(SDK_NAME "${OPENDAQ_SDK_NAME}")

# 32-bit Linux cross-compilation setup (must be before any project())
if (NOT DEFINED PROJECT_SOURCE_DIR AND OPENDAQ_FORCE_COMPILE_32BIT AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    opendaq_32bit_build_linux_early_setup()
endif()

project(${REPO_NAME} LANGUAGES CXX)

opendaq_common_early_setup()

# Keep a user-wide vcpkg MSBuild integration ("vcpkg integrate install") out of this build: it adds its own
# include folder, with a different Boost version, to every Visual Studio project
if (CMAKE_GENERATOR MATCHES "Visual Studio")
    list(APPEND CMAKE_VS_GLOBALS "VcpkgEnabled=false")
endif()

# Where openDAQ core and the modules the tests use come from:
#   SOURCES   fetched and built together with the tests (cmake/FromSources.cmake)
#   PREBUILT  installed ones: core and module stagings, a bundle or an installed SOURCES build; only the test apps
#             are built (cmake/FromPrebuilt.cmake)
set(OPENDAQ_INTEGRATION_TESTS_FROM "SOURCES" CACHE STRING "Where openDAQ core and the modules come from: SOURCES or PREBUILT")
set_property(CACHE OPENDAQ_INTEGRATION_TESTS_FROM PROPERTY STRINGS SOURCES PREBUILT)
if (NOT OPENDAQ_INTEGRATION_TESTS_FROM STREQUAL "SOURCES" AND NOT OPENDAQ_INTEGRATION_TESTS_FROM STREQUAL "PREBUILT")
    message(FATAL_ERROR "OPENDAQ_INTEGRATION_TESTS_FROM must be SOURCES or PREBUILT, not \"${OPENDAQ_INTEGRATION_TESTS_FROM}\"")
endif()
message(STATUS "openDAQ core and modules from: ${OPENDAQ_INTEGRATION_TESTS_FROM}")

# options
set(OPENDAQ_ENABLE_UNITY_LIBS ON CACHE BOOL "Unity builds for libraries")
opendaq_setup_common_build_options()
opendaq_setup_project_specific_build_options(${REPO_OPTION_PREFIX})
option(OPENDAQ_ENABLE_REGRESSION_TESTS "Enable regression testing" OFF)

if (OPENDAQ_ENABLE_REGRESSION_TESTS AND NOT OPENDAQ_INTEGRATION_TESTS_FROM STREQUAL "SOURCES")
    message(FATAL_ERROR "OPENDAQ_ENABLE_REGRESSION_TESTS needs OPENDAQ_INTEGRATION_TESTS_FROM=SOURCES")
endif()

opendaq_common_compile_targets_settings()
opendaq_setup_compiler_flags(${REPO_OPTION_PREFIX})

if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 10)
    add_compile_options(-Wno-unknown-warning-option)
endif()

enable_testing()

# Branch, tag or commit of each fetched repository: read from its *_ref file unless given as -D<REF_VAR>=<ref>
function(integration_tests_read_ref REF_VAR REF_FILE)
    if (NOT DEFINED ${REF_VAR})
        opendaq_read_file_contents("${PROJECT_SOURCE_DIR}/${REF_FILE}" REF)
        set(${REF_VAR} "${REF}" PARENT_SCOPE)
    endif()
endfunction()

find_package(Git REQUIRED)

function(integration_tests_print_commit REPO REF)
    string(TOLOWER ${REPO} REPO_LOWER)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse HEAD
        WORKING_DIRECTORY "${${REPO_LOWER}_SOURCE_DIR}"
        OUTPUT_VARIABLE COMMIT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    message(STATUS "${REPO} at ${REF}: ${COMMIT}")
endfunction()

# The modules the test apps load from their binaries (integration_tests_use_modules() in integration/CMakeLists.txt),
# by the base name of their binaries ([lib]<name>-<version>[-debug].module.<dll|so|dylib>)
set(INTEGRATION_TESTS_MODULES
    native_stream_srv_module
    native_stream_cl_module
    ws_stream_srv_module
    ws_stream_cl_module
    opcua_server_module
    opcua_client_module
    ref_device_module
    ref_fb_module
)

# Provides what integration/ needs: daq::opendaq, daq::opendaq_mocks, daq::test_utils, the opendaq_test_* CMake
# functions, the directory-level defines core compiles with, INTEGRATION_TESTS_MODULE_FILE_<module> (the module
# binaries the tests load), OPENDAQ_INTEGRATION_TESTS_LT_TLS and LT_MODULES_SOURCE_DIR
if (OPENDAQ_INTEGRATION_TESTS_FROM STREQUAL "SOURCES")
    include(cmake/FromSources.cmake)
else()
    include(cmake/FromPrebuilt.cmake)
endif()

opendaq_set_cmake_folder_context(TARGET_FOLDER_NAME)

add_subdirectory(integration)

if (OPENDAQ_ENABLE_REGRESSION_TESTS)
    add_subdirectory(regression)
endif()

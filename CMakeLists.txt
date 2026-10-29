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

# Branch, tag or commit of each fetched repository: read from its *_ref file unless given as -D<REF_VAR>=<ref>
function(integration_tests_read_ref REF_VAR REF_FILE)
    if (NOT DEFINED ${REF_VAR})
        opendaq_read_file_contents("${PROJECT_SOURCE_DIR}/${REF_FILE}" REF)
        set(${REF_VAR} "${REF}" PARENT_SCOPE)
    endif()
endfunction()

integration_tests_read_ref(OPENDAQ_REF opendaq_ref)
integration_tests_read_ref(LT_MODULES_REF lt_modules_ref)
integration_tests_read_ref(OPCUA_MODULES_REF opcua_modules_ref)

# options
set(OPENDAQ_ENABLE_UNITY_LIBS ON CACHE BOOL "Unity builds for libraries")
opendaq_setup_common_build_options()
opendaq_setup_project_specific_build_options(${REPO_OPTION_PREFIX})
option(OPENDAQ_ENABLE_REGRESSION_TESTS "Enable regression testing" OFF)

opendaq_common_compile_targets_settings()
opendaq_setup_compiler_flags(${REPO_OPTION_PREFIX})

if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 10)
    add_compile_options(-Wno-unknown-warning-option)
endif()

enable_testing()

# Parts of openDAQ core the tests use
set(OPENDAQ_ENABLE_TESTS OFF CACHE BOOL "")
set(OPENDAQ_ENABLE_TEST_UTILS ON CACHE BOOL "")
set(OPENDAQ_ENABLE_NATIVE_STREAMING ON CACHE BOOL "")
set(DAQMODULES_OPENDAQ_CLIENT_MODULE ON CACHE BOOL "")
set(DAQMODULES_OPENDAQ_SERVER_MODULE ON CACHE BOOL "")
set(DAQMODULES_REF_DEVICE_MODULE ON CACHE BOOL "")
set(DAQMODULES_REF_FB_MODULE ON CACHE BOOL "")

# This project adds the OPC UA and LT streaming modules itself, so core must not fetch its own copies
foreach(CORE_OPTION OPENDAQ_ENABLE_OPCUA OPENDAQ_ENABLE_WEBSOCKET_STREAMING)
    if (${CORE_OPTION})
        message(FATAL_ERROR "${CORE_OPTION} must be OFF: ${REPO_NAME} adds the OPC UA and LT streaming modules itself")
    endif()
endforeach()

# Modules the tests use; tests and example apps of the module projects stay off when they are subprojects
set(DAQMODULES_LT_STREAMING_ENABLE_CLIENT ON CACHE BOOL "")
set(DAQMODULES_LT_STREAMING_ENABLE_SERVER ON CACHE BOOL "")
set(DAQMODULES_LT_STREAMING_ENABLE_TLS ON CACHE BOOL "")
set(DAQMODULES_OPCUA_ENABLE_CLIENT ON CACHE BOOL "")
set(DAQMODULES_OPCUA_ENABLE_SERVER ON CACHE BOOL "")

include(FetchContent)

# The module projects are fetched before core but added after it: their Boost components have to be
# registered before core sets up Boost (the same order as core's external_modules/)
opendaq_get_custom_fetch_content_params(LtStreamingModulesModern FC_PARAMS)
FetchContent_Declare(
    LtStreamingModulesModern
    GIT_REPOSITORY https://github.com/openDAQ/LTStreamingModulesModern.git
    GIT_TAG        ${LT_MODULES_REF}
    GIT_PROGRESS   ON
    GIT_SHALLOW    OFF
    SOURCE_SUBDIR  "INVALID"
    GIT_REMOTE_UPDATE_STRATEGY CHECKOUT
    ${FC_PARAMS}
)

opendaq_get_custom_fetch_content_params(OpcUaModules FC_PARAMS)
FetchContent_Declare(
    OpcUaModules
    GIT_REPOSITORY https://github.com/openDAQ/OpcUaModules.git
    GIT_TAG        ${OPCUA_MODULES_REF}
    GIT_PROGRESS   ON
    GIT_SHALLOW    OFF
    SOURCE_SUBDIR  "INVALID"
    GIT_REMOTE_UPDATE_STRATEGY CHECKOUT
    ${FC_PARAMS}
)

FetchContent_MakeAvailable(LtStreamingModulesModern OpcUaModules)

include("${ltstreamingmodulesmodern_SOURCE_DIR}/external/boost/Boost.cmake")
include("${opcuamodules_SOURCE_DIR}/external/boost/Boost.cmake")

opendaq_get_custom_fetch_content_params(${OPENDAQ_SDK_NAME} FC_PARAMS)
FetchContent_Declare(
    ${OPENDAQ_SDK_NAME}
    GIT_REPOSITORY https://github.com/openDAQ/openDAQ.git
    GIT_TAG        ${OPENDAQ_REF}
    GIT_PROGRESS   ON
    GIT_REMOTE_UPDATE_STRATEGY CHECKOUT
    ${FC_PARAMS}
)
FetchContent_MakeAvailable(${OPENDAQ_SDK_NAME})

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

integration_tests_print_commit(${OPENDAQ_SDK_NAME} ${OPENDAQ_REF})
integration_tests_print_commit(LtStreamingModulesModern ${LT_MODULES_REF})
integration_tests_print_commit(OpcUaModules ${OPCUA_MODULES_REF})

# Core sets the following on its own directory only. Repeat them for the modules and tests added below, so
# they compile the core headers the same way the core libraries were compiled. The LT streaming switches
# are left out on purpose: the tests take them from the LT modules project.
list(APPEND CMAKE_MODULE_PATH "${opendaq_SOURCE_DIR}/cmake")
find_package(Filesystem REQUIRED COMPONENTS Final Experimental)

include(openDAQLogging)
opendaq_log_level_str_to_int(${OPENDAQ_LOG_LEVEL_DEBUG} OPENDAQ_LOG_LEVEL_DEBUG_INT)
opendaq_log_level_str_to_int(${OPENDAQ_LOG_LEVEL_RELEASE} OPENDAQ_LOG_LEVEL_RELEASE_INT)
add_compile_definitions(OPENDAQ_LOG_LEVEL=$<IF:$<CONFIG:Debug>,${OPENDAQ_LOG_LEVEL_DEBUG_INT},${OPENDAQ_LOG_LEVEL_RELEASE_INT}>)

add_compile_definitions(BOOST_ALL_NO_LIB=1)

foreach(CORE_DEFINE OPENDAQ_ENABLE_ERROR_GUARD
                    OPENDAQ_ENABLE_NATIVE_STREAMING
                    OPENDAQ_ENABLE_OPTIONAL_TESTS
                    OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS
                    OPENDAQ_MIMALLOC_SUPPORT)
    if (${CORE_DEFINE})
        add_compile_definitions(${CORE_DEFINE})
    endif()
endforeach()

# Core forces OPENDAQ_SKIP_UNSTABLE_TESTS on (as a non-cache variable) while unstable test labels are off
if (NOT OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS OR OPENDAQ_SKIP_UNSTABLE_TESTS)
    add_compile_definitions(OPENDAQ_SKIP_UNSTABLE_TESTS)
endif()

if (OPENDAQ_CI_RUNNER)
    add_compile_definitions(DS_CI_RUNNER=1)
endif()

add_subdirectory("${ltstreamingmodulesmodern_SOURCE_DIR}" "${ltstreamingmodulesmodern_BINARY_DIR}")
add_subdirectory("${opcuamodules_SOURCE_DIR}" "${opcuamodules_BINARY_DIR}")

# Used by the tests to find the LT streaming TLS fixtures
set(LT_MODULES_SOURCE_DIR "${ltstreamingmodulesmodern_SOURCE_DIR}")

opendaq_set_cmake_folder_context(TARGET_FOLDER_NAME)

add_subdirectory(integration)

if (OPENDAQ_ENABLE_REGRESSION_TESTS)
    add_subdirectory(regression)
endif()

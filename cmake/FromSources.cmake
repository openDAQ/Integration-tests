# OPENDAQ_INTEGRATION_TESTS_FROM=SOURCES: fetch openDAQ core and the OPC UA and LT streaming modules and build them
# together with the test apps. Included by the root CMakeLists.txt.

integration_tests_read_ref(OPENDAQ_REF opendaq_ref)
integration_tests_read_ref(LT_MODULES_REF lt_modules_ref)
integration_tests_read_ref(OPCUA_MODULES_REF opcua_modules_ref)

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

# The secure channel tests follow the LT modules project
set(OPENDAQ_INTEGRATION_TESTS_LT_TLS ${DAQMODULES_LT_STREAMING_ENABLE_TLS})

# The test apps load the modules from the binaries these targets build (integration/CMakeLists.txt):
# integration_tests_use_modules() makes the apps depend on the targets and passes them the binaries' paths
foreach(MODULE ${INTEGRATION_TESTS_MODULES})
    if (NOT TARGET daq::${MODULE})
        message(FATAL_ERROR "Module target daq::${MODULE} was not created: check the options that enable it "
                            "(DAQMODULES_*)")
    endif()

    get_target_property(MODULE_TARGET daq::${MODULE} ALIASED_TARGET)
    if (NOT MODULE_TARGET)
        set(MODULE_TARGET daq::${MODULE})
    endif()

    set(INTEGRATION_TESTS_MODULE_TARGET_${MODULE} ${MODULE_TARGET})
    set(INTEGRATION_TESTS_MODULE_FILE_${MODULE} "$<TARGET_FILE:${MODULE_TARGET}>")
endforeach()

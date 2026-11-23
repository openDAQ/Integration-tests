# OPENDAQ_INTEGRATION_TESTS_FROM=PREBUILT: openDAQ core and the modules come installed, nothing of them is built
# here. Included by the root CMakeLists.txt.
#
#   CMAKE_PREFIX_PATH                         the core prefix: an unpacked core staging (its root on Windows,
#                                             <staging>/opt/opendaq on Linux and macOS), a bundle prefix, or
#                                             `cmake --install` of a SOURCES build
#   OPENDAQ_INTEGRATION_TESTS_MODULE_DIRS     more folders with module binaries, e.g. the module stagings'
#                                             bin/modules (Windows) or lib/modules; the core's modules folder is
#                                             always searched
#   OPENDAQ_INTEGRATION_TESTS_RUNTIME_DIRS    folders the tests need on the library search path, e.g. the OpenSSL 3
#                                             DLLs of the LT streaming modules on Windows
#   OPENDAQ_INTEGRATION_TESTS_LT_TLS          run the LT streaming tests over the secure channel (default ON)
#   LT_MODULES_REF                            the LTStreamingModulesModern revision the LT staging was built from
#                                             (the TLS fixtures come from its sources); FETCHCONTENT_SOURCE_DIR_
#                                             LTSTREAMINGMODULESMODERN points at an existing checkout instead

list(APPEND CMAKE_MESSAGE_CONTEXT prebuilt)

# Release only: the stagings are Release builds, and MSVC cannot link their static libraries (opendaq_mocks) into
# a Debug executable
get_property(INTEGRATION_TESTS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if (INTEGRATION_TESTS_MULTI_CONFIG)
    if (NOT CMAKE_CONFIGURATION_TYPES STREQUAL "Release")
        message(FATAL_ERROR "OPENDAQ_INTEGRATION_TESTS_FROM=PREBUILT supports only the Release configuration: "
                            "configure with -DCMAKE_CONFIGURATION_TYPES=Release (the *-prebuilt presets do), "
                            "not \"${CMAKE_CONFIGURATION_TYPES}\"")
    endif()
elseif (NOT CMAKE_BUILD_TYPE STREQUAL "Release")
    message(FATAL_ERROR "OPENDAQ_INTEGRATION_TESTS_FROM=PREBUILT supports only CMAKE_BUILD_TYPE=Release, "
                        "not \"${CMAKE_BUILD_TYPE}\"")
endif()

if (OPENDAQ_ENABLE_COVERAGE)
    message(FATAL_ERROR "OPENDAQ_ENABLE_COVERAGE needs OPENDAQ_INTEGRATION_TESTS_FROM=SOURCES")
endif()

# --- openDAQ core ------------------------------------------------------------------------------------------------

find_package(${OPENDAQ_SDK_NAME} REQUIRED CONFIG)
message(STATUS "${OPENDAQ_SDK_NAME} ${${OPENDAQ_SDK_NAME}_VERSION} from ${${OPENDAQ_SDK_NAME}_DIR}")

set(INTEGRATION_TESTS_MISSING_TARGETS "")
foreach(CORE_TARGET daq::opendaq daq::opendaq_mocks daq::opendaq_test_utils)
    if (NOT TARGET ${CORE_TARGET})
        list(APPEND INTEGRATION_TESTS_MISSING_TARGETS ${CORE_TARGET})
    endif()
endforeach()
if (INTEGRATION_TESTS_MISSING_TARGETS)
    list(JOIN INTEGRATION_TESTS_MISSING_TARGETS ", " INTEGRATION_TESTS_MISSING_TARGETS)
    message(FATAL_ERROR "The ${OPENDAQ_SDK_NAME} package in ${${OPENDAQ_SDK_NAME}_DIR} lacks "
                        "${INTEGRATION_TESTS_MISSING_TARGETS}. The core has to be built with OPENDAQ_ENABLE_TEST_UTILS "
                        "and packed with its \"External\" install component (core's stagings have both since core #1377, "
                        "whose \"stage\" preset turns the test utilities on)")
endif()

# config_protocol: the tests use only GetLatestConfigProtocolVersion(), an inline constexpr of its header. Cores that do
# not install the library (none does yet) get its headers from core's sources at the staged commit, which build against
# the installed core headers alone. Drop this once every supported core installs config_protocol.
set(OPENDAQ_INTEGRATION_TESTS_CONFIG_PROTOCOL_INCLUDE_DIR "" CACHE PATH
    "Core's shared/libraries/config_protocol/include at the staged core commit, for a core that does not install config_protocol")
if (NOT TARGET daq::config_protocol)
    if (NOT EXISTS "${OPENDAQ_INTEGRATION_TESTS_CONFIG_PROTOCOL_INCLUDE_DIR}/config_protocol/config_protocol.h")
        message(FATAL_ERROR "The ${OPENDAQ_SDK_NAME} package in ${${OPENDAQ_SDK_NAME}_DIR} has no daq::config_protocol. Set "
                            "OPENDAQ_INTEGRATION_TESTS_CONFIG_PROTOCOL_INCLUDE_DIR to core's "
                            "shared/libraries/config_protocol/include at the staged core commit "
                            "(.github/scripts/fetch_sources.py --opendaq <sha> puts core in build/_src/openDAQ)")
    endif()
    add_library(daq::config_protocol INTERFACE IMPORTED GLOBAL)
    set_target_properties(daq::config_protocol PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${OPENDAQ_INTEGRATION_TESTS_CONFIG_PROTOCOL_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES daq::opendaq)
    message(STATUS "daq::config_protocol: headers only, from ${OPENDAQ_INTEGRATION_TESTS_CONFIG_PROTOCOL_INCLUDE_DIR}")
else()
    message(STATUS "daq::config_protocol: from the ${OPENDAQ_SDK_NAME} package")
endif()

# CMake helpers of core's that it does not install (copies, see the files)
include(${CMAKE_CURRENT_LIST_DIR}/prebuilt/openDAQTestResources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/prebuilt/openDAQLogging.cmake)

# --- Defines -----------------------------------------------------------------------------------------------------

# Core compiles with these on its own directory, and installed cores do not record them. They change what the core
# headers mean, so they have to match the core build: the values of core's "stage" preset (Release).
# Revisit when core records them (in its package config or on daq::opendaq).
set(OPENDAQ_LOG_LEVEL_RELEASE "Info" CACHE STRING "Compile time logging level; must match the core build")
set_property(CACHE OPENDAQ_LOG_LEVEL_RELEASE PROPERTY STRINGS ${OPENDAQ_LOG_LEVELS})
opendaq_log_level_str_to_int(${OPENDAQ_LOG_LEVEL_RELEASE} OPENDAQ_LOG_LEVEL_RELEASE_INT)
add_compile_definitions(OPENDAQ_LOG_LEVEL=${OPENDAQ_LOG_LEVEL_RELEASE_INT})

add_compile_definitions(OPENDAQ_ENABLE_NATIVE_STREAMING)
# Not defined, as in the stage build: OPENDAQ_ENABLE_ERROR_GUARD, OPENDAQ_MIMALLOC_SUPPORT,
# OPENDAQ_ENABLE_OPTIONAL_TESTS

# Test-side switches, with the values of the "ci" preset as defaults
include(CMakeDependentOption)
option(OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS "Enable labeling unstable tests" ON)
cmake_dependent_option(OPENDAQ_SKIP_UNSTABLE_TESTS "Skip tests marked as unstable" ON "OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS" ON)
option(OPENDAQ_CI_RUNNER "Tests run in the CI (defines DS_CI_RUNNER)" ON)

if (OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS)
    add_compile_definitions(OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS)
endif()

# As core: OPENDAQ_SKIP_UNSTABLE_TESTS is on while unstable test labels are off
if (NOT OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS OR OPENDAQ_SKIP_UNSTABLE_TESTS)
    add_compile_definitions(OPENDAQ_SKIP_UNSTABLE_TESTS)
endif()

if (OPENDAQ_CI_RUNNER)
    add_compile_definitions(DS_CI_RUNNER=1)
endif()

# --- GoogleTest and test utils (after the defines: the test utils compile with them) -----------------------------

add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/prebuilt/gtest ${CMAKE_BINARY_DIR}/prebuilt/gtest)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/prebuilt/testutils ${CMAKE_BINARY_DIR}/prebuilt/testutils)

# --- Module binaries ---------------------------------------------------------------------------------------------

set(OPENDAQ_INTEGRATION_TESTS_MODULE_DIRS "" CACHE STRING
    "More folders with module binaries (e.g. the module stagings' bin/modules or lib/modules); the core's modules folder is always searched")

cmake_path(CONVERT "${OPENDAQ_INTEGRATION_TESTS_MODULE_DIRS}" TO_CMAKE_PATH_LIST INTEGRATION_TESTS_EXTRA_MODULE_DIRS NORMALIZE)
set(INTEGRATION_TESTS_PREBUILT_MODULE_DIRS ${OPENDAQ_MODULES_DIR} ${INTEGRATION_TESTS_EXTRA_MODULE_DIRS})
list(REMOVE_DUPLICATES INTEGRATION_TESTS_PREBUILT_MODULE_DIRS)

foreach(MODULE_DIR ${INTEGRATION_TESTS_PREBUILT_MODULE_DIRS})
    if (NOT IS_DIRECTORY "${MODULE_DIR}")
        message(FATAL_ERROR "Module folder ${MODULE_DIR} does not exist")
    endif()
    message(STATUS "Module folder: ${MODULE_DIR}")
endforeach()

# Every module the tests use must be there exactly once, so an incomplete set of stagings fails here and not in
# the tests
string(REPLACE "." "\\." INTEGRATION_TESTS_MODULE_SUFFIX_REGEX "${OPENDAQ_MODULE_SUFFIX}")
set(INTEGRATION_TESTS_MODULE_FILES "")
set(INTEGRATION_TESTS_MODULE_PROBLEMS "")
foreach(MODULE ${INTEGRATION_TESTS_MODULES})
    set(MODULE_FILES "")
    foreach(MODULE_DIR ${INTEGRATION_TESTS_PREBUILT_MODULE_DIRS})
        file(GLOB FOUND_FILES LIST_DIRECTORIES false
             "${MODULE_DIR}/${MODULE}-*${OPENDAQ_MODULE_SUFFIX}"
             "${MODULE_DIR}/lib${MODULE}-*${OPENDAQ_MODULE_SUFFIX}"
        )
        list(APPEND MODULE_FILES ${FOUND_FILES})
    endforeach()
    list(FILTER MODULE_FILES EXCLUDE REGEX "-debug${INTEGRATION_TESTS_MODULE_SUFFIX_REGEX}$")
    list(REMOVE_DUPLICATES MODULE_FILES)

    list(LENGTH MODULE_FILES MODULE_FILE_COUNT)
    if (MODULE_FILE_COUNT EQUAL 1)
        message(STATUS "Module ${MODULE}: ${MODULE_FILES}")
        list(APPEND INTEGRATION_TESTS_MODULE_FILES ${MODULE_FILES})
        cmake_path(GET MODULE_FILES FILENAME INTEGRATION_TESTS_MODULE_FILE_NAME_${MODULE})
    elseif (MODULE_FILE_COUNT EQUAL 0)
        list(APPEND INTEGRATION_TESTS_MODULE_PROBLEMS "${MODULE}: not found")
    else()
        list(JOIN MODULE_FILES ", " MODULE_FILES)
        list(APPEND INTEGRATION_TESTS_MODULE_PROBLEMS "${MODULE}: several binaries (${MODULE_FILES})")
    endif()
endforeach()
if (INTEGRATION_TESTS_MODULE_PROBLEMS)
    list(JOIN INTEGRATION_TESTS_MODULE_PROBLEMS "\n  " INTEGRATION_TESTS_MODULE_PROBLEMS)
    message(FATAL_ERROR "Module binaries ([lib]<module>-*${OPENDAQ_MODULE_SUFFIX}) in the module folders:\n"
                        "  ${INTEGRATION_TESTS_MODULE_PROBLEMS}\n"
                        "Add the folders of the missing module stagings to OPENDAQ_INTEGRATION_TESTS_MODULE_DIRS.")
endif()

# The tests use the modules from a copy in the "modules" folder next to the test apps, the layout of an installed
# bin/modules, as in SOURCES mode the modules are built next to the test apps. Some tests let core's module manager
# load the modules from the program folder (module path ""), which it searches recursively; the other tests load
# them by path (INTEGRATION_TESTS_MODULE_FILE_<module>) from the same copy, so no module is loaded from two places.
# The test apps are written to CMAKE_RUNTIME_OUTPUT_DIRECTORY (opendaq_common_compile_targets_settings()).
if (CMAKE_RUNTIME_OUTPUT_DIRECTORY STREQUAL "")
    message(FATAL_ERROR "CMAKE_RUNTIME_OUTPUT_DIRECTORY must be set: the module binaries are copied next to the test apps")
endif()
if (INTEGRATION_TESTS_MULTI_CONFIG)
    set(INTEGRATION_TESTS_MODULE_COPY_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/modules")
else()
    set(INTEGRATION_TESTS_MODULE_COPY_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/modules")
endif()

set(INTEGRATION_TESTS_MODULE_COPIES "")
foreach(MODULE_FILE ${INTEGRATION_TESTS_MODULE_FILES})
    cmake_path(GET MODULE_FILE FILENAME MODULE_FILE_NAME)
    list(APPEND INTEGRATION_TESTS_MODULE_COPIES "${INTEGRATION_TESTS_MODULE_COPY_DIR}/${MODULE_FILE_NAME}")
endforeach()

add_custom_command(
    OUTPUT  ${INTEGRATION_TESTS_MODULE_COPIES}
    COMMAND ${CMAKE_COMMAND} -E make_directory "${INTEGRATION_TESTS_MODULE_COPY_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy ${INTEGRATION_TESTS_MODULE_FILES} "${INTEGRATION_TESTS_MODULE_COPY_DIR}"
    COMMAND ${CMAKE_COMMAND} -E touch ${INTEGRATION_TESTS_MODULE_COPIES}
    DEPENDS ${INTEGRATION_TESTS_MODULE_FILES}
    COMMENT "Copying the prebuilt module binaries next to the test apps"
    VERBATIM
)
# integration_tests_use_modules() makes the test apps depend on it
add_custom_target(integration_test_modules DEPENDS ${INTEGRATION_TESTS_MODULE_COPIES})
set_target_properties(integration_test_modules PROPERTIES FOLDER "cmake/prebuilt")

# The paths integration_tests_use_modules() passes to the test apps
foreach(MODULE ${INTEGRATION_TESTS_MODULES})
    set(INTEGRATION_TESTS_MODULE_FILE_${MODULE}
        "${INTEGRATION_TESTS_MODULE_COPY_DIR}/${INTEGRATION_TESTS_MODULE_FILE_NAME_${MODULE}}")
endforeach()

# --- Runtime environment of the tests ----------------------------------------------------------------------------

set(OPENDAQ_INTEGRATION_TESTS_RUNTIME_DIRS "" CACHE STRING
    "Folders the tests need on the library search path (e.g. the OpenSSL 3 bin folder on Windows)")
cmake_path(CONVERT "${OPENDAQ_INTEGRATION_TESTS_RUNTIME_DIRS}" TO_CMAKE_PATH_LIST INTEGRATION_TESTS_RUNTIME_DIRS NORMALIZE)

# Applied to every test, the gtest shards included (integration_tests_apply_test_environment()). Linux and macOS
# need nothing for core: the test apps get the core library folder as their build RPATH.
if (WIN32)
    set(INTEGRATION_TESTS_PATH_VARIABLE PATH)
elseif (APPLE)
    set(INTEGRATION_TESTS_PATH_VARIABLE DYLD_LIBRARY_PATH)
else()
    set(INTEGRATION_TESTS_PATH_VARIABLE LD_LIBRARY_PATH)
endif()

set(INTEGRATION_TESTS_TEST_ENVIRONMENT "")
foreach(RUNTIME_DIR ${INTEGRATION_TESTS_RUNTIME_DIRS})
    if (NOT IS_DIRECTORY "${RUNTIME_DIR}")
        message(FATAL_ERROR "Runtime folder ${RUNTIME_DIR} does not exist")
    endif()
    message(STATUS "Runtime folder: ${RUNTIME_DIR}")
    list(APPEND INTEGRATION_TESTS_TEST_ENVIRONMENT "${INTEGRATION_TESTS_PATH_VARIABLE}=path_list_prepend:${RUNTIME_DIR}")
endforeach()
if (WIN32)
    # Prepended last, so it comes first: the core DLLs
    list(APPEND INTEGRATION_TESTS_TEST_ENVIRONMENT "PATH=path_list_prepend:$<TARGET_FILE_DIR:daq::opendaq>")
endif()

# --- LT streaming TLS fixtures -----------------------------------------------------------------------------------

option(OPENDAQ_INTEGRATION_TESTS_LT_TLS
       "Run the LT streaming tests over the secure channel (LT module binaries built with DAQMODULES_LT_STREAMING_ENABLE_TLS, the default)"
       ON)

if (OPENDAQ_INTEGRATION_TESTS_LT_TLS)
    if (NOT DEFINED LT_MODULES_REF)
        message(FATAL_ERROR "LT_MODULES_REF is not set: the LT streaming TLS tests take their fixtures from the "
                            "LTStreamingModulesModern sources at the revision the LT staging was built from (its "
                            "org.opencontainers.image.revision annotation). Or turn OPENDAQ_INTEGRATION_TESTS_LT_TLS off.")
    endif()

    # Download only, as in SOURCES mode (the same FetchContent name, so FETCHCONTENT_SOURCE_DIR_LTSTREAMINGMODULESMODERN
    # works the same way)
    include(FetchContent)
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
    FetchContent_MakeAvailable(LtStreamingModulesModern)
    integration_tests_print_commit(LtStreamingModulesModern ${LT_MODULES_REF})

    set(LT_MODULES_SOURCE_DIR "${ltstreamingmodulesmodern_SOURCE_DIR}")
endif()

list(POP_BACK CMAKE_MESSAGE_CONTEXT)

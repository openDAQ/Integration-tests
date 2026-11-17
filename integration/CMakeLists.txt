opendaq_set_cmake_folder_context(TARGET_FOLDER_NAME)

if (MSVC)
    add_compile_options(/wd4100)
endif()

if (POLICY CMP0077)
    cmake_policy(SET CMP0077 NEW)
endif()

# Every test app of this project is required: stop when an option it needs is off instead of skipping it.
# Only in SOURCES mode: in PREBUILT mode the module binaries are checked instead (cmake/FromPrebuilt.cmake).
function(integration_tests_require_options TEST_DIR)
    if (NOT OPENDAQ_INTEGRATION_TESTS_FROM STREQUAL "SOURCES")
        return()
    endif()

    set(MISSING_OPTIONS "")
    foreach(REQUIRED_OPTION ${ARGN})
        if (NOT ${REQUIRED_OPTION})
            list(APPEND MISSING_OPTIONS ${REQUIRED_OPTION})
        endif()
    endforeach()

    if (MISSING_OPTIONS)
        list(JOIN MISSING_OPTIONS ", " MISSING_OPTIONS)
        message(FATAL_ERROR "${TEST_DIR} needs these options ON: ${MISSING_OPTIONS}")
    endif()
endfunction()

# integration_tests_use_modules(<app> <module>...): <app> loads these modules from their binaries with core's
# IModuleManager::loadModule. The apps do not link the modules; each gets the path of every module it uses as
# INTEGRATION_TESTS_MODULE_FILE_<module> (set by cmake/From<mode>.cmake), so a test that uses a module its app does not
# list here does not compile. In SOURCES mode the app depends on the module targets; in PREBUILT mode on the copy of
# the module binaries next to it (integration_test_modules, cmake/FromPrebuilt.cmake).
function(integration_tests_use_modules APP)
    if (TARGET integration_test_modules)
        add_dependencies(${APP} integration_test_modules)
    endif()

    foreach(MODULE ${ARGN})
        if (NOT MODULE IN_LIST INTEGRATION_TESTS_MODULES)
            message(FATAL_ERROR "${APP} uses module ${MODULE}, which is not in INTEGRATION_TESTS_MODULES")
        endif()
        if (NOT INTEGRATION_TESTS_MODULE_FILE_${MODULE})
            message(FATAL_ERROR "No binary path for module ${MODULE} (INTEGRATION_TESTS_MODULE_FILE_${MODULE})")
        endif()
        if (INTEGRATION_TESTS_MODULE_TARGET_${MODULE})
            add_dependencies(${APP} ${INTEGRATION_TESTS_MODULE_TARGET_${MODULE}})
        endif()
        target_compile_definitions(${APP} PRIVATE
            "INTEGRATION_TESTS_MODULE_FILE_${MODULE}=\"${INTEGRATION_TESTS_MODULE_FILE_${MODULE}}\""
        )
    endforeach()
endfunction()

# integration_tests_apply_test_environment(): adds INTEGRATION_TESTS_TEST_ENVIRONMENT (ENVIRONMENT_MODIFICATION entries,
# set in PREBUILT mode: the library search path) to every test of the calling directory. Call it after the tests.
function(integration_tests_apply_test_environment)
    if (NOT INTEGRATION_TESTS_TEST_ENVIRONMENT)
        return()
    endif()

    get_property(DIRECTORY_TESTS DIRECTORY PROPERTY TESTS)
    foreach(TEST_NAME ${DIRECTORY_TESTS})
        set_property(TEST ${TEST_NAME} APPEND PROPERTY ENVIRONMENT_MODIFICATION ${INTEGRATION_TESTS_TEST_ENVIRONMENT})
    endforeach()
endfunction()

integration_tests_require_options(test_ref_modules
    DAQMODULES_REF_FB_MODULE
    DAQMODULES_REF_DEVICE_MODULE
)
message(STATUS "Reference device & function block module test app")
add_subdirectory(test_ref_modules)

# The OPC UA and LT streaming switches come from the module projects, the rest from core
integration_tests_require_options(test_opendaq_device_modules
    DAQMODULES_OPENDAQ_CLIENT_MODULE
    DAQMODULES_OPENDAQ_SERVER_MODULE
    OPENDAQ_ENABLE_NATIVE_STREAMING
    DAQMODULES_LT_STREAMING_ENABLE_CLIENT
    DAQMODULES_LT_STREAMING_ENABLE_SERVER
    DAQMODULES_OPCUA_ENABLE_CLIENT
    DAQMODULES_OPCUA_ENABLE_SERVER
    DAQMODULES_REF_FB_MODULE
    DAQMODULES_REF_DEVICE_MODULE
)
message(STATUS "${SDK_NAME} device and server module test app")
add_subdirectory(test_opendaq_device_modules)

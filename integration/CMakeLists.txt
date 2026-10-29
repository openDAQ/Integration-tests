opendaq_set_cmake_folder_context(TARGET_FOLDER_NAME)

if (MSVC)
    add_compile_options(/wd4100)
endif()

if (POLICY CMP0077)
    cmake_policy(SET CMP0077 NEW)
endif()

# Every test app of this project is required: stop when an option it needs is off instead of skipping it
function(integration_tests_require_options TEST_DIR)
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

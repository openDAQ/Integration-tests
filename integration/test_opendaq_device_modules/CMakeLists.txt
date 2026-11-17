# Set before the apps are created: $<TARGET_FILE_DIR> of an app then adds no dependency on it (lt_tls_secrets below)
cmake_policy(SET CMP0112 NEW)

set(TEST_HEADERS
    test_helpers/test_helpers.h
    test_helpers/device_modules.h
    test_helpers/lt_tls.h
)

# The tests that advertise over mDNS or scan for devices: one binary, one ctest entry holding every network lock
set(TEST_APP test_device_modules)
set(TEST_SOURCES test_native_device_modules.cpp
                 test_opcua_device_modules.cpp
                 test_default_config.cpp
                 test_app.cpp
                 test_websocket_modules.cpp
                 test_native_streaming_modules.cpp
                 test_device_discovery.cpp
                 test_remote_update.cpp
)

# The tests that never touch mDNS: gtest shards on shifted ports, running concurrently with everything else
set(STREAMING_TEST_APP test_device_modules_streaming)
set(STREAMING_TEST_SOURCES test_app.cpp
                           test_streaming.cpp
                           test_subdevices.cpp
                           test_device_locking.cpp
)
set(STREAMING_TEST_SHARDS 4)

function(add_device_modules_test_app APP)
    add_executable(${APP}
        ${TEST_HEADERS}
        ${ARGN}
    )

    # The modules are not linked: the tests load them from their binaries (integration_tests_use_modules())
    target_link_libraries(${APP} PRIVATE daq::test_utils
                                         daq::opendaq
                                         daq::opendaq_mocks
                                         daq::config_protocol
    )

    integration_tests_use_modules(${APP}
        native_stream_srv_module
        native_stream_cl_module
        ws_stream_srv_module
        ws_stream_cl_module
        opcua_server_module
        opcua_client_module
        ref_device_module
        ref_fb_module
    )

    # getaddrinfo in test_helpers.h
    if (WIN32)
        target_link_libraries(${APP} PRIVATE ws2_32)
    endif()

    # The secure channel tests of the LT streaming modules. The LT modules keep their own
    # DAQMODULES_LT_STREAMING_ENABLE_TLS to themselves, so the tests get it from this project
    if (OPENDAQ_INTEGRATION_TESTS_LT_TLS)
        target_compile_definitions(${APP} PRIVATE DAQMODULES_LT_STREAMING_ENABLE_TLS)
    endif()

    if (MSVC)
        target_compile_options(${APP} PRIVATE /bigobj)
    endif()

    opendaq_target_pch(${APP} <opendaq/opendaq.h> <gtest/gtest.h>)
    opendaq_target_unity_tests(${APP} BATCH_SIZE 4)

    # opendaq_mocks is a static library whose headers declare its factories PUBLIC_EXPORT: keep that from meaning
    # __declspec(dllimport)
    target_compile_definitions(${APP} PRIVATE OPENDAQ_SKIP_DLL_IMPORT)

    set_target_properties(${APP} PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY $<TARGET_FILE_DIR:${APP}>)

    if (OPENDAQ_ENABLE_COVERAGE)
        setup_target_for_coverage(${APP}coverage ${APP} ${APP}coverage)
    endif()
endfunction()

# Too large to merge into a unity translation unit: MSVC hits an internal compiler error.
set_source_files_properties(test_native_device_modules.cpp PROPERTIES SKIP_UNITY_BUILD_INCLUSION ON)

add_device_modules_test_app(${TEST_APP} ${TEST_SOURCES})
add_device_modules_test_app(${STREAMING_TEST_APP} ${STREAMING_TEST_SOURCES})

# The LT streaming tests over the secure channel need TLS fixtures (CA, server and client
# certificates/keys). Reuse the pre-generated ones from the LT streaming modules repository instead of
# keeping a second copy here. Only needed when the LT modules are built with the secure channel.
if (OPENDAQ_INTEGRATION_TESTS_LT_TLS)
    set(LT_TLS_SECRETS_DIR "${LT_MODULES_SOURCE_DIR}/tests/integration/secrets")
    if (NOT EXISTS "${LT_TLS_SECRETS_DIR}")
        message(FATAL_ERROR "TLS fixtures not found in ${LT_TLS_SECRETS_DIR}. "
                            "The LT streaming tests over the secure channel need them to load their secrets.")
    endif()

    # One copy for both apps: they share an output directory, and two parallel copies into it fail on Windows
    add_custom_target(lt_tls_secrets
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${LT_TLS_SECRETS_DIR}
                $<TARGET_FILE_DIR:${TEST_APP}>/secrets)
    add_dependencies(${TEST_APP} lt_tls_secrets)
    add_dependencies(${STREAMING_TEST_APP} lt_tls_secrets)
endif()

add_test(NAME ${TEST_APP}
         COMMAND $<TARGET_FILE_NAME:${TEST_APP}>
         WORKING_DIRECTORY $<TARGET_FILE_DIR:${TEST_APP}>
)
opendaq_test_resource_lock(${TEST_APP} network_native network_lt network_opcua mdns)
set_tests_properties(${TEST_APP} PROPERTIES PROCESSORS 2)

opendaq_add_test_shards(${STREAMING_TEST_APP} ${STREAMING_TEST_SHARDS})

integration_tests_apply_test_environment()

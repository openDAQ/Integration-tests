set(TEST_APP test_ref_modules)

set(TEST_SOURCES
    classifier_test_helper.h
    test_ref_modules.cpp
    test_app.cpp
)

add_executable(${TEST_APP} ${TEST_SOURCES}
)

# The modules are not linked: the tests load them from their binaries (integration_tests_use_modules())
target_link_libraries(${TEST_APP}
    PRIVATE
        daq::test_utils
        daq::opendaq
)

integration_tests_use_modules(${TEST_APP}
    ref_device_module
    ref_fb_module
)

opendaq_target_pch_group(${TEST_APP} opendaq_tests <opendaq/opendaq.h> <gtest/gtest.h>)

add_test(NAME ${TEST_APP}
         COMMAND $<TARGET_FILE_NAME:${TEST_APP}>
         WORKING_DIRECTORY $<TARGET_FILE_DIR:${TEST_APP}>
)

set_target_properties(${TEST_APP} PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY $<TARGET_FILE_DIR:${TEST_APP}>)

integration_tests_apply_test_environment()

if (OPENDAQ_ENABLE_COVERAGE)
    setup_target_for_coverage(${TEST_APP}coverage ${TEST_APP} ${TEST_APP}coverage)
endif()

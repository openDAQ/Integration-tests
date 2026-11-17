# daq::test_utils for PREBUILT mode. Installed cores ship only daq::opendaq_test_utils, an interface library whose
# base_test_listener.h has neither TEST_F/P_UNSTABLE_SKIPPED nor the skipping of unstable tests. This builds core's
# real one from the copies in this folder (see include/testutils/base_test_listener.h) on top of the installed
# headers, under the name the test apps link (daq::test_utils).
#
# The copied header has to win over the installed one of the same name: this target's include directory is a
# normal one, listed before those of the imported targets it links (system include directories). If the
# installed header won, TEST_F_UNSTABLE_SKIPPED would be undefined and the test apps would not compile.
set(LIB_NAME integration_test_utils)

add_library(${LIB_NAME} STATIC
    include/testutils/base_test_listener.h
    src/base_test_listener.cpp
)
add_library(daq::test_utils ALIAS ${LIB_NAME})

target_include_directories(${LIB_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_link_libraries(${LIB_NAME} PUBLIC daq::opendaq_test_utils
                                         daq::opendaq
                                         GTest::gtest
                                         GTest::gmock
)

target_compile_features(${LIB_NAME} PUBLIC cxx_std_17)

if (MSVC)
    # OnTestStart does not use its parameter when OPENDAQ_SKIP_UNSTABLE_TESTS is off
    target_compile_options(${LIB_NAME} PRIVATE /wd4100)
endif()

set_target_properties(${LIB_NAME} PROPERTIES FOLDER "cmake/prebuilt")

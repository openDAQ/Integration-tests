# GoogleTest for PREBUILT mode: installed cores do not ship it. Same version, download and settings as core
# (external/gtest/CMakeLists.txt, GTest_REQUIREDVERSION); the same FetchContent name, so the download in
# FETCHCONTENT_EXTERNALS_DIR is shared with SOURCES builds.
list(APPEND CMAKE_MESSAGE_CONTEXT googletest)

# Like core's external/: warnings of third-party code are not errors here, and its CMake may use the directory
# commands opendaq-cmake-utils bans in "MODERN" mode (googletest calls include_directories())
opendaq_ignore_compiler_warnings()
opendaq_get_cmake_mode(INTEGRATION_TESTS_SAVED_CMAKE_MODE)
opendaq_set_cmake_mode(ANCIENT)

set(INTEGRATION_TESTS_GTEST_VERSION "1.17.0")
message(STATUS "Fetching GTest version ${INTEGRATION_TESTS_GTEST_VERSION}")

include(FetchContent)
opendaq_get_custom_fetch_content_params(GTest FC_PARAMS)

set(INSTALL_GTEST OFF)
# /MD like core and the stagings
set(gtest_force_shared_crt ON)

FetchContent_Declare(
    GTest
    URL      https://github.com/google/googletest/archive/v${INTEGRATION_TESTS_GTEST_VERSION}.zip
    URL_HASH SHA256=40d4ec942217dcc84a9ebe2a68584ada7d4a33a8ee958755763278ea1c5e18ff
    ${FC_PARAMS}
)
FetchContent_MakeAvailable(GTest)
opendaq_set_cmake_mode(${INTEGRATION_TESTS_SAVED_CMAKE_MODE})

foreach(GTEST_TARGET gtest gtest_main gmock gmock_main)
    if (TARGET ${GTEST_TARGET})
        set_target_properties(${GTEST_TARGET} PROPERTIES FOLDER "external/gtest")
    endif()
endforeach()

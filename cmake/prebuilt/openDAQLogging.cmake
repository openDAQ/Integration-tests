# Copy of openDAQ cmake/openDAQLogging.cmake at ee6b12178ae0d4e619c7845cd07e6cced10ba5c7
# (opendaq_log_level_str_to_int).
# Core does not install it: remove the copy once core installs it or opendaq-cmake-utils provides it.
# Used in PREBUILT mode only; SOURCES mode takes core's own.

set(OPENDAQ_LOG_LEVELS Trace Debug Info Warning Error Critical Off)

function(opendaq_log_level_str_to_int STR RET)
    string(TOLOWER ${STR} STR)
    if(${STR} STREQUAL "trace")
        set(${RET} 0 PARENT_SCOPE)
    elseif(${STR} STREQUAL "debug")
        set(${RET} 1 PARENT_SCOPE)
    elseif(${STR} STREQUAL "info")
        set(${RET} 2 PARENT_SCOPE)
    elseif(${STR} STREQUAL "warning")
        set(${RET} 3 PARENT_SCOPE)
    elseif(${STR} STREQUAL "error")
        set(${RET} 4 PARENT_SCOPE)
    elseif(${STR} STREQUAL "critical")
        set(${RET} 5 PARENT_SCOPE)
    elseif(${STR} STREQUAL "off")
        set(${RET} 6 PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Log level should be one of ${OPENDAQ_LOG_LEVELS}")
    endif()
endfunction()

# CMake Build System Options for the openDAQ Integration Tests

This project builds openDAQ core, the OPC UA modules and the LT streaming modules from source and builds the integration tests against them.
The following options might be used to customize the build passing them in the **configure step** like so: `-D<option_name>=<value>`.

## Table of contents:
* [Source versions](#source-versions)
* [Project options](#project-options)
* [Core and module options set by this project](#core-and-module-options-set-by-this-project)
* [Core settings passed on to the tests](#core-settings-passed-on-to-the-tests)
* [Other options](#other-options)

## Source versions
| Option Name | Type | Default Value | Description | Conditions, if any |
|-|-|-|-|-|
| `OPENDAQ_REF` | String | Contents of `opendaq_ref` | Branch, tag or commit of [openDAQ core](https://github.com/openDAQ/openDAQ) | - |
| `LT_MODULES_REF` | String | Contents of `lt_modules_ref` | Branch, tag or commit of [LTStreamingModulesModern](https://github.com/openDAQ/LTStreamingModulesModern) | - |
| `OPCUA_MODULES_REF` | String | Contents of `opcua_modules_ref` | Branch, tag or commit of [OpcUaModules](https://github.com/openDAQ/OpcUaModules) | - |

A branch is followed: every configure moves to its latest commit. The commits in use are printed during the configure step (`<repository> at <ref>: <commit>`).
A value given with `-D` stays in the cache; remove it with `-U<option_name>` to go back to the ref file.

## Project options
| Option Name | Type | Default Value | Description | Conditions, if any |
|-|-|-|-|-|
| `OPENDAQ_ENABLE_REGRESSION_TESTS` | Bool | `OFF` | Build the protocol level regression tests in `regression/`, that run as a part of GitHub Actions | Uses Linux-only link options |
| `OPENDAQ_INTEGRATION_TESTS_DEBUG_WARNINGS_AS_ERRORS` | Bool | `OFF` | Treat debug warnings as errors | - |
| `OPENDAQ_INTEGRATION_TESTS_RELEASE_WARNINGS_AS_ERRORS` | Bool | `ON` | Treat release warnings as errors | - |
| `FETCHCONTENT_EXTERNALS_DIR` | Path | `<build folder>/__external` | Folder for the downloaded sources of core, the modules and their dependencies | The presets set it to `build/_ext`, shared by all build folders |

## Core and module options set by this project
The root `CMakeLists.txt` sets these before core and the modules are configured. Options marked *Required* must stay `ON`; apart from `OPENDAQ_ENABLE_TEST_UTILS`, the integration tests check them and stop the configure step with a list of the ones that are `OFF`.

| Option Name | Project | Value | Description | Conditions, if any |
|-|-|-|-|-|
| `OPENDAQ_ENABLE_TESTS` | core | `OFF` | Core's own unit tests | - |
| `OPENDAQ_ENABLE_TEST_UTILS` | core | `ON` | gtest, test utilities and mocks | Required |
| `OPENDAQ_ENABLE_NATIVE_STREAMING` | core | `ON` | Native streaming | Required |
| `DAQMODULES_OPENDAQ_CLIENT_MODULE` | core | `ON` | Native client module | Required |
| `DAQMODULES_OPENDAQ_SERVER_MODULE` | core | `ON` | Native server module | Required |
| `DAQMODULES_REF_DEVICE_MODULE` | core | `ON` | Reference device module | Required |
| `DAQMODULES_REF_FB_MODULE` | core | `ON` | Reference function block module | Required |
| `DAQMODULES_LT_STREAMING_ENABLE_CLIENT` | LT streaming | `ON` | LT streaming client module | Required |
| `DAQMODULES_LT_STREAMING_ENABLE_SERVER` | LT streaming | `ON` | LT streaming server module | Required |
| `DAQMODULES_LT_STREAMING_ENABLE_TLS` | LT streaming | `ON` | TLS (`daq.lts://`) channel of the LT streaming modules | When `OFF`, the tests over the secure channel are left out and OpenSSL is not needed |
| `DAQMODULES_OPCUA_ENABLE_CLIENT` | OPC UA | `ON` | OPC UA client module | Required |
| `DAQMODULES_OPCUA_ENABLE_SERVER` | OPC UA | `ON` | OPC UA server module | Required |

`OPENDAQ_ENABLE_OPCUA` and `OPENDAQ_ENABLE_WEBSOCKET_STREAMING` must stay `OFF`: this project adds the OPC UA and LT streaming modules itself, and the configure step stops when either is `ON`.
The tests and example applications of the module projects stay `OFF`, their default when they are built as subprojects.

## Core settings passed on to the tests
Core applies these to its own folder only. This project repeats them for the tests and the modules, so that they compile the core headers the same way the core libraries were compiled. `BOOST_ALL_NO_LIB=1` is always repeated.

| Option Name | Type | Default Value | Description | Conditions, if any |
|-|-|-|-|-|
| `OPENDAQ_LOG_LEVEL_DEBUG` | String | `Debug` | Compile time logging level for debug builds | - |
| `OPENDAQ_LOG_LEVEL_RELEASE` | String | `Info` | Compile time logging level for release builds | - |
| `OPENDAQ_ENABLE_ERROR_GUARD` | Bool | `OFF` | Enable error guard | Forced `ON` when `CMAKE_BUILD_TYPE` is `Debug` (single-configuration generators) |
| `OPENDAQ_ENABLE_OPTIONAL_TESTS` | Bool | `OFF` | Enable optional (debugging) tests | - |
| `OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS` | Bool | `OFF` | Enable labeling unstable tests.<Br>When the option value is ON, the `UNSTABLE_SKIPPED_` prefix is added to all tests defined as `TEST_F_UNSTABLE_SKIPPED` or `TEST_P_UNSTABLE_SKIPPED` | - |
| `OPENDAQ_SKIP_UNSTABLE_TESTS` | Bool | `ON` | Skip tests marked as unstable | Only relevant if `OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS` is ON |
| `OPENDAQ_MIMALLOC_SUPPORT` | Bool | `OFF` | Enable MiMalloc-based packet allocator | - |
| `OPENDAQ_CI_RUNNER` | Bool | `OFF` | Configure as a CI runner (`DS_CI_RUNNER`) | - |

## Other options
These come from [opendaq-cmake-utils](https://github.com/openDAQ/opendaq-cmake-utils) and apply to core, the modules and the tests alike.
For all other options see [core's CMake options](https://github.com/openDAQ/openDAQ/blob/main/CMake-Options.md) and the module repositories.

| Option Name | Type | Default Value | Description | Conditions, if any |
|-|-|-|-|-|
| `OPENDAQ_USE_CCACHE` | Bool | `ON` | Use compiler cache driver if available | Only used with the Ninja and Makefiles generators |
| `OPENDAQ_ENABLE_BUILD_ACCELERATION` | Bool | `ON` | Precompiled headers and unity builds | - |
| `OPENDAQ_MSVC_SINGLE_PROCESS_BUILD` | Bool | `OFF` | Do not include /MP compile option | Only relevant for MSVC |
| `OPENDAQ_LINK_RUNTIME_STATICALLY` | Bool | `OFF` | Link the C++ runtime statically (embed it) | - |
| `OPENDAQ_LINK_3RD_PARTY_LIBS_STATICALY` | Bool | `ON` | Link the 3rd party libraries statically (embed it) | - |
| `OPENDAQ_DISABLE_DEBUG_POSTFIX` | Bool | `OFF` | Disable debug ('-debug') postfix | - |

# Integration-tests
Integration tests for openDAQ. They run openDAQ core together with the OPC UA and LT streaming modules:

| Test app | Covers |
|-|-|
| `test_ref_modules` | Reference device and function block modules |
| `test_device_modules` | Native, OPC UA and LT streaming device modules, default configuration, discovery, remote update |
| `test_device_modules_streaming` | Streaming, subdevices and device locking, run as 4 gtest shards |

## How the build works
This project is the top-level CMake project. The configure step fetches:

| Repository | Ref file | Default |
|-|-|-|
| [openDAQ core](https://github.com/openDAQ/openDAQ) | `opendaq_ref` | `Integration_test_removal` |
| [LTStreamingModulesModern](https://github.com/openDAQ/LTStreamingModulesModern) | `lt_modules_ref` | `main` |
| [OpcUaModules](https://github.com/openDAQ/OpcUaModules) | `opcua_modules_ref` | `main` |

Branches are followed: every configure moves to their latest commit and prints the commits in use.
Core is built without its own tests and without its OPC UA and LT streaming options; this project adds those modules itself.
See [CMake-Options.md](CMake-Options.md) for the options.

The test apps do not link the modules: they load the module binaries and create the modules from them, the way core's module manager does. That is what lets them run against prebuilt core and modules as well (see [Building against prebuilt core and modules](#building-against-prebuilt-core-and-modules)).

## Requirements
* CMake 3.25 or newer
* Windows: Visual Studio 2022 or 2026. Linux: GCC or Clang, and Ninja
* Git. On Windows, turn on long paths: `git config --global core.longpaths true`
* OpenSSL, for the TLS channel of the LT streaming modules. On Windows it is found in `C:\Program Files\OpenSSL-Win64`; elsewhere set `OPENSSL_ROOT_DIR`. To build without it, configure with `-DDAQMODULES_LT_STREAMING_ENABLE_TLS=OFF` (the tests over the TLS channel are then left out)

## Build and run
Windows, Visual Studio 2022:
```
cmake --preset msvc22
cmake --build --preset msvc22-release
ctest --preset msvc22-release
```
Use `msvc22-debug` for a Debug build and test run. Linux uses `gcc-release`, `gcc-debug`, `clang-release` or `clang-debug` for all three steps. `cmake --list-presets=all` lists the presets.

* The build folder is `build/<configure preset>`, and the test apps are written to its `bin` folder.
* Downloaded sources are kept in `build/_ext` and shared by all presets.
* The build presets build the three test apps and everything they link.
* Visual Studio builds switch off vcpkg's user-wide MSBuild integration (`vcpkg integrate install`). It would otherwise add vcpkg's include folder, with its own Boost version, to every project and break the Boost build.

## Running the tests
* `ctest` runs 6 entries: `test_ref_modules`, `test_device_modules` and `test_device_modules_streaming_0` to `_3`.
* The tests open TCP ports 4840-4843 (OPC UA), 7414-7415 (LT streaming) and 7420-7422 (native), and use mDNS. The streaming shards use the same ports shifted by 1000 to 4000. Windows Firewall may ask for access the first time.
* Tests that share ports or mDNS are locked against each other, so they can run in parallel: `ctest --preset msvc22-release -j 8`.
* To run single tests, start a test app from the `bin` folder with `--gtest_filter=<pattern>`.
* The test apps do not link the modules. Each test loads the modules it needs with core's module manager (`IModuleManager::loadModule`), from the module binaries the build points the test apps to: where the module targets are built, or, with prebuilt modules, the `modules` folder next to the test apps.

## Building against local clones
To build against a local checkout instead of fetching a repository, pass its path at configure time:
```
-DFETCHCONTENT_SOURCE_DIR_OPENDAQ=<path to openDAQ>
-DFETCHCONTENT_SOURCE_DIR_LTSTREAMINGMODULESMODERN=<path to LTStreamingModulesModern>
-DFETCHCONTENT_SOURCE_DIR_OPCUAMODULES=<path to OpcUaModules>
```

## Building against prebuilt core and modules
With `-DOPENDAQ_INTEGRATION_TESTS_FROM=PREBUILT` nothing of core and the modules is fetched or built: the configure step finds an installed core with `find_package(openDAQ)` and only the three test apps are built. Release only. For example, with unpacked core, OPC UA and LT streaming stagings on Windows:
```
cmake --preset msvc22-prebuilt -DCMAKE_PREFIX_PATH=<core staging> -DOPENDAQ_INTEGRATION_TESTS_MODULE_DIRS="<OPC UA staging>/bin/modules;<LT staging>/bin/modules" -DOPENDAQ_INTEGRATION_TESTS_RUNTIME_DIRS="C:/Program Files/OpenSSL-Win64/bin" -DLT_MODULES_REF=<commit of the LT staging> -DOPENDAQ_INTEGRATION_TESTS_CONFIG_PROTOCOL_INCLUDE_DIR=<core checkout at the staged commit>/shared/libraries/config_protocol/include
cmake --build --preset msvc22-prebuilt
ctest --preset msvc22-prebuilt
```
* The core has to come with its test utilities and mocks (built with `OPENDAQ_ENABLE_TEST_UTILS`). Core's stagings have them since core's `stage` preset turned them on (openDAQ#1377); `cmake --install` of a build of this project's default mode also works as the core prefix.
* The configure step checks that every module the tests use is found exactly once, in the core's modules folder or in `OPENDAQ_INTEGRATION_TESTS_MODULE_DIRS`. The build copies them to the `modules` folder next to the test apps, and the tests load them from there.
* The LT streaming TLS fixtures come from the LTStreamingModulesModern sources at `LT_MODULES_REF`.
* Cores do not install config_protocol yet: its headers come from core's sources at the staged commit (`python .github/scripts/fetch_sources.py --opendaq <commit>` puts core in `build/_src/openDAQ`).
* The workflow `integration-tests-prebuilt.yml` does the same in GitHub Actions. Started by hand, it pulls the stagings from ghcr. Called by another workflow (`workflow_call`), it takes them from ghcr or from the artifacts of the caller's run (input `staging-source`); its header lists what a caller has to provide.
* See [CMake-Options.md](CMake-Options.md#prebuilt-core-and-modules) for all the options.

## Regression tests
The protocol level regression tests in `regression/` are not part of this build. They are made for GitHub Actions, use Linux-only link options, and are enabled with `-DOPENDAQ_ENABLE_REGRESSION_TESTS=ON`.

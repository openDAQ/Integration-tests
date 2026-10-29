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

## Building against local clones
To build against a local checkout instead of fetching a repository, pass its path at configure time:
```
-DFETCHCONTENT_SOURCE_DIR_OPENDAQ=<path to openDAQ>
-DFETCHCONTENT_SOURCE_DIR_LTSTREAMINGMODULESMODERN=<path to LTStreamingModulesModern>
-DFETCHCONTENT_SOURCE_DIR_OPCUAMODULES=<path to OpcUaModules>
```

## Regression tests
The protocol level regression tests in `regression/` are not part of this build. They are made for GitHub Actions, use Linux-only link options, and are enabled with `-DOPENDAQ_ENABLE_REGRESSION_TESTS=ON`.

/*
 * Copyright 2022-2026 openDAQ d.o.o.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma once
#include <opendaq/instance_ptr.h>
#include <opendaq/module_manager_ptr.h>

// The modules are not linked into the test apps: the instance's module manager loads them from their binaries.
// The build passes their paths as INTEGRATION_TESTS_MODULE_FILE_<module> (integration_tests_use_modules()).

inline void addNativeServerModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_native_stream_srv_module);
}

inline void addNativeClientModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_native_stream_cl_module);
}

inline void addLtServerModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_ws_stream_srv_module);
}

inline void addLtClientModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_ws_stream_cl_module);
}

inline void addOpcuaServerModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_opcua_server_module);
}

inline void addOpcuaClientModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_opcua_client_module);
}

inline void addRefDeviceModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_ref_device_module);
}

inline void addRefFBModule(const daq::InstancePtr& instance)
{
    instance.getModuleManager().loadModule(INTEGRATION_TESTS_MODULE_FILE_ref_fb_module);
}

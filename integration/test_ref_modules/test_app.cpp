// Cores before openDAQ #1382 do not install the two init headers: declare the functions the way they do
// (remove the fallbacks once every core the tests run against installs them)
#if __has_include(<opendaq/module_manager_init.h>)
    #include <opendaq/module_manager_init.h>
#else
    #include <coretypes/common.h>
    extern "C" daq::ErrCode PUBLIC_EXPORT daqInitModuleManagerLibrary(void);
#endif
#if __has_include(<opendaq/opendaq_init.h>)
    #include <opendaq/opendaq_init.h>
#else
    #include <coretypes/common.h>
    extern "C" daq::ErrCode PUBLIC_EXPORT daqInitOpenDaqLibrary(void);
#endif
#include <coreobjects/util.h>
#include <testutils/daq_memcheck_listener.h>


int main(int argc, char** args)
{
    daq::daqInitializeCoreObjectsTesting();
    daqInitModuleManagerLibrary();
    daqInitOpenDaqLibrary();

    testing::InitGoogleTest(&argc, args);

    testing::TestEventListeners& listeners = testing::UnitTest::GetInstance()->listeners();
    listeners.Append(new DaqMemCheckListener());

    auto res = RUN_ALL_TESTS();
    return res;
}

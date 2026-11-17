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

// Copy of openDAQ shared/libraries/testutils/include/internal/testutils/base_test_listener.h at ee6b12178ae0d4e619c7845cd07e6cced10ba5c7.
// Installed cores ship only the include/installed variant (BaseTestListener = EmptyTestEventListener, without
// TEST_F/P_UNSTABLE_SKIPPED); PREBUILT mode builds this one (cmake/prebuilt/testutils) and puts it ahead of the
// installed one. Remove the copy once core installs the real test utils.

#pragma once
#include <gtest/gtest.h>

#ifndef OPENDAQ_ENABLE_UNSTABLE_TEST_LABELS
#   define TEST_F_UNSTABLE_SKIPPED TEST_F
#   define TEST_P_UNSTABLE_SKIPPED TEST_P
#else
    // ReSharper disable CppInconsistentNaming
#   define TEST_F_UNSTABLE_SKIPPED(test_fixture, test_name)  TEST_F(test_fixture, UNSTABLE_SKIPPED_##test_name)
#   define TEST_P_UNSTABLE_SKIPPED(test_fixture, test_name)  TEST_P(test_fixture, UNSTABLE_SKIPPED_##test_name)
    // ReSharper restore CppInconsistentNaming
#endif

class BaseTestListener : public ::testing::EmptyTestEventListener
{
protected:
    void OnTestStart(const testing::TestInfo& info) override;
    void OnTestEnd(const testing::TestInfo& info) override;
};

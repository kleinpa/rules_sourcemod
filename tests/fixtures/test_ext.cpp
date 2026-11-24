// Fixture for rules_sourcemod analysis tests. The tests assert on providers, but
// the extension is really compiled and linked, so this has to build for real.
#include "smsdk_ext.h"

namespace {
SDKExtension g_test_extension;
}  // namespace

SMEXT_LINK(&g_test_extension);

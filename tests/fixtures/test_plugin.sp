// Fixture for rules_sourcemod analysis tests. The tests assert on providers, but
// building this target really does run spcomp, so it has to compile for real.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mylib/math_util>
#include <test_ext_natives>

#if !defined TEST_FLAG
 #error "expected TEST_FLAG define from sourcemod_plugin(defines = ...)"
#endif

public void OnPluginStart() {
    if (ClampInt(100, 0, 10) == -1) {
        TestExt_Ping(1);
    }
}

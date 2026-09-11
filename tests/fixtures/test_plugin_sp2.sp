// Fixture for rules_sourcemod's SourcePawn 2 coverage. Deliberately uses what
// only the 2.0 compiler accepts -- returning a heap array from a function and
// the intrinsic `.size` property -- so this compiles under `sourcepawn_version
// = "2"` and cannot under "1". The classic fixture, test_plugin.sp, is the one
// both compilers take.
#include <sourcemod>

int[] MakeArray(int n) {
    return new int[n];
}

public void OnPluginStart() {
    int[] cells = MakeArray(4);
    PrintToServer("%d", cells.size);
}

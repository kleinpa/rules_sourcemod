# SourceMod Standard Library Natives in `sourcemod_test`

## Current State (`spshell`)

`sourcemod_test` currently runs compiled `.smx` test binaries inside upstream's
standalone `spshell` (`sourcepawn/tools/spshell/spshell.cpp`), which embeds only
`sourcepawn_vm` plus `<spshell>` / `<float>` intrinsics (`assert_*`, `print*`,
and `float` operators). Any test that calls SourceMod's own natives (`StrEqual`,
`Format`, `ArrayList`, `StringMap`, `DataPack`, etc.) fails at load time with
`unbound native`.

## Architectural Key: `core/logic/` Already Has Almost Everything

SourceMod splits its runtime cleanly in two across `bridge/include/BridgeAPI.h`:

- **`core/` (`sourcemod.<engine>.so/.dll`)** — Engine-coupled layer linking
  HL2SDK and Metamod (`ConVar`, entities, clients, game events, menus, `tier1`
  `KeyValues`).
- **`core/logic/` (`sourcemod.logic.so/.dll`, `@sourcemod_sdk//:logic`)** —
  100% engine-independent C++ library with **zero HL2SDK or `srcds` dependency**.

Inspecting `sourcemod/sdk.BUILD.bazel` (`logic_srcs`) and
`core/logic/common_logic.cpp` shows that virtually the entire pure-data SourceMod
standard library lives inside `core/logic/`:

| Subsystem / Source            | Natives & Methodmaps Provided                                                       |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| `smn_strings.cpp` + `sprintf` | `Format`, `FormatEx`, `VFormat`, `StrEqual`, `strcmp`, `StrContains`, `StrCat`, `StrCopy`, `ReplaceString`, `ExplodeString`, `TrimString`, `StringToInt`, `FloatToString`, UTF-8 helpers |
| `smn_adt_array.cpp`           | `ArrayList` (`CreateArray`, `PushArrayCell`, `PushArrayString`, `GetArray*`, `SortADTArray`, ...) |
| `smn_adt_trie.cpp`            | `StringMap` & `StringMapSnapshot` (`CreateTrie`, `SetTrieValue`, `GetTrieString`, ...) |
| `smn_adt_stack.cpp`           | `ArrayStack` (`CreateStack`, `PushStack*`, `PopStack*`, ...)                        |
| `smn_datapacks.cpp`           | `DataPack` (`CreateDataPack`, `WritePack*`, `ReadPack*`, ...)                       |
| `smn_handles.cpp` + `HandleSys.cpp` | `Handle` lifecycle (`CloseHandle`, `CloneHandle`, `delete` operator on methodmaps) |
| `smn_float.cpp`               | SourceMod's `<float>` natives (`__FLOAT_MUL__`, `RoundToNearest`, `Sine`, `Pow`, `GetURandomFloat`, ...) — eliminating the separate `spcomp/float.inc` shim |
| `smn_sorting.cpp`             | `SortIntegers`, `SortFloats`, `SortStrings`, custom Pawn comparator callbacks       |
| `smn_functions.cpp` / `ForwardSys.cpp` | Private/global `Forward`s (`Call_StartFunction`, `Call_Push*`, `Call_Finish`) |
| `smn_textparse.cpp`           | `SMCParser` text/config parser                                                      |
| `smn_filesystem.cpp`          | `File`, `DirectoryListing`, `OpenFile`, `BuildPath`                                 |
| `PluginSys.cpp` / `ShareSys.cpp` / `ExtensionSys.cpp` | `.smx` plugin loader, `g_CoreNatives` registration, and engine-independent `.ext` loading |

*(Notable exception: `KeyValues` (`core/smn_keyvalues.cpp`) lives in `core/`
because it wraps HL2SDK `tier1`'s `KeyValues` class, not `srcds`.)*

## How `core/logic` Boots (`common_logic.cpp`)

`core/logic` exposes a single C entrypoint (`logic_load(SM_LOGIC_MAGIC)` ->
`logic_init(CoreProvider* core, sm_logic_t* logic)`):

1. Every subsystem and `REGISTER_NATIVES(...)` block (`CoreNativesToAdd`) in
   `core/logic/*.cpp` registers itself on the `SMGlobalClass::head` linked list
   during static initialization.
2. `logic_init` copies pointers from `CoreProvider` (`spe1`/`spe2` from
   `sourcepawn_vm`, `ISourceMod`, `ITimerSystem`, `ServerGlobals`, etc.),
   initializes `g_ShareSys`, and returns `sm_logic_t` (whose `head` points to the
   `SMGlobalClass` chain).
3. Iterating `SMGlobalClass::head->OnSourceModAllInitialized()` populates
   `g_CoreNatives` with every `sp_nativeinfo_t` table in `core/logic`.

## Implementation Sketch: Headless `sm_test_runner`

Instead of reimplementing SourceMod's standard library in Pawn stocks, build a
small C++ runner binary (`//spcomp:sm_test_runner`, replacing or augmenting
`spshell_runner.cc`) that:

1. Loads `sourcepawn_vm` (`GetSourcePawnFactory`) and `sourcemod.logic`
   (`logic_load(SM_LOGIC_MAGIC)`).
2. Supplies a minimal headless `CoreProvider` + `ISourceMod` implementation:
   - Real `BuildPath` rooted at Bazel's `TEST_TMPDIR` (so `File` / `SMCParser` /
     translation tests work hermetically).
   - Logging / `GenerateError` wired to `stderr` + non-zero test exit flag.
   - Null or stubbed engine pointers (`engine`, `playerhelpers`, `gamehelpers`,
     `menus`) that fail cleanly if a unit test accidentally invokes an in-game
     entity/client native.
3. Registers assertion natives (`assert_eq`, `assert_true`, `assert_false`,
   `assert_streq`), loads the test `.smx` via `g_PluginSys` (binding all
   `g_CoreNatives` automatically), and invokes `main()` (or every `public Test_*()`
   function for multi-case test files).

### Bonus: Testing Engine-Independent C++ Extensions Headlessly

Because `g_Extensions` (`ExtensionSys`) and `g_ShareSys` also live inside
`core/logic`, the same headless host can load engine-independent
`sourcemod_extension` binaries (`regex.ext`, `clientprefs.ext`, `dbi.sqlite.ext`,
or user extensions without `branch = ...`), letting extension authors run real
end-to-end Pawn -> C++ native tests under `bazel test` with no `srcds` install.

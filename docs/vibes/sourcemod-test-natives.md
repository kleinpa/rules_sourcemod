# SourceMod Natives in `sourcemod_test`

`sourcemod_test` runs plugins in upstream's `spshell`
(`sourcepawn/vm/shell/shell.cpp`), which provides only the SourcePawn VM and the
natives in `<spshell>` and `<float>`. A test that calls a SourceMod native
(`Format`, `strcmp`, `ArrayList`, ...) compiles, but fails at that call because
the native is unbound.

## Approach: host `sourcemod.logic`

SourceMod is split into two libraries that communicate through
`bridge/include/BridgeAPI.h`:

- **`core/`** (`sourcemod.<engine>`) links the HL2SDK and Metamod: convars,
  entities, clients, events, menus.
- **`core/logic/`** (`sourcemod.logic`, `@sourcemod_sdk//:logic`) uses neither the
  HL2SDK nor `srcds`, and implements most engine-independent natives:

| Source in `core/logic/`                        | Provides                                                                           |
| ---------------------------------------------- | ---------------------------------------------------------------------------------- |
| `smn_string.cpp`, `sprintf.cpp`                | `Format`, `strcmp`, `StrContains`, `ReplaceString`, `TrimString`, `StringToInt`, ... |
| `smn_adt_array.cpp`                            | `ArrayList`                                                                        |
| `smn_adt_trie.cpp`                             | `StringMap`, `StringMapSnapshot`                                                   |
| `smn_adt_stack.cpp`                            | `ArrayStack`                                                                       |
| `smn_datapacks.cpp`                            | `DataPack`                                                                         |
| `smn_handles.cpp`, `HandleSys.cpp`             | Handle lifecycle (`CloseHandle`, `CloneHandle`, `delete`)                          |
| `smn_float.cpp`                                | SourceMod's `<float>` natives, making the `spcomp/float.inc` shim unnecessary      |
| `smn_sorting.cpp`                              | `SortIntegers`, `SortCustom1D`, `ArrayList.Sort`, ...                              |
| `smn_functions.cpp`, `ForwardSys.cpp`          | Forwards and `Call_*`                                                              |
| `smn_textparse.cpp`                            | `SMCParser`                                                                        |
| `smn_filesystem.cpp`                           | `File`, `DirectoryListing`, `BuildPath`                                            |
| `PluginSys.cpp`, `ShareSys.cpp`, `ExtensionSys.cpp` | Plugin loading, native binding, extension loading                             |

Stocks built on these, such as `StrEqual` and `ExplodeString`, work as well.
`KeyValues` does not: it lives in `core/` because it wraps the HL2SDK's
`KeyValues` class.

## Runner design

A new C++ binary, `//spcomp:sm_test_runner`, would:

1. Load `sourcepawn_vm` and `sourcemod.logic`.
2. Call `logic_load(SM_LOGIC_MAGIC)`, then the returned
   `logic_init(CoreProvider*, sm_logic_t*)`, with a minimal `CoreProvider` and
   `ISourceMod`:
   - `BuildPath` rooted at `TEST_TMPDIR`, so file and translation tests are
     hermetic.
   - Logging sent to `stderr`; plugin errors recorded to fail the test.
   - Stub engine, player, game, and menu interfaces that report a clear error
     when used.
3. Walk the `SMGlobalClass` list in `sm_logic_t.head`, calling
   `OnSourceModStartup(false)`, `OnSourceModAllInitialized()`, and
   `OnSourceModAllInitialized_Post()` in that order, as `core/sourcemod.cpp` does.
   The second pass registers logic's natives. (`logic_init` resets
   `SMGlobalClass::head` itself to the host's listeners, so walk the returned
   `head`.)
4. Register the assertion natives, load the test `.smx` through the plugin system
   (which binds the natives), and run `main()` or each `public Test_*()`.

The main risk is subsystems that use host interfaces during startup. Each one
needs a stub that satisfies it.

## Extension tests

Because `ExtensionSys` is also in `core/logic/`, the runner could load extensions
built without a `branch` and test Pawn-to-C++ calls without `srcds`. `regex` is a
good first target. `clientprefs` and `topmenus` register client listeners, so they
need a working player-manager stub.

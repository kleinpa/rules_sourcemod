# Upstream SourceMod Build Parity

## Missing extensions

Extensions in upstream's `AMBuildScript` that `sourcemod/sdk.BUILD.bazel` does not
build:

| Extension | Output          | Needs                                                                       | Notes                                                                                              |
| --------- | --------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `dhooks`  | `dhooks.ext`    | `CDetour`, `safetyhook`; on x86, `sourcepawn/vm/x86/assembler-x86.cpp`      | Windows x86 / x64 and Linux x86; upstream skips Linux x64                                          |
| `updater` | `updater.ext`   | `webternet.ext` at runtime                                                  | Core loads it at startup to update `gamedata/` unless `DisableAutoUpdate` is `"yes"`. Make it opt-in; image contents should not change at runtime |
| `pgsql`   | `dbi.pgsql.ext` | In-tree prebuilt `libpq`; zlib on Linux                                     | Opt-in                                                                                             |
| `mysql`   | `dbi.mysql.ext` | External MySQL client library                                               | Opt-in; the only one needing a library that is not in the tree                                     |

## `libstdc++` linking

Upstream links `libstdc++` statically. Bazel links with the C driver and an
explicit `-lstdc++`, so extensions, SourceMod libraries, and the Metamod cores
all need `libstdc++.so.6`.

The `//linux` toolchain limits that requirement to `GLIBCXX_3.4.28`, so this is
harmless on Debian 11 or newer. Link `-l:libstdc++.a` everywhere only if servers
with an older `libstdc++` need to be supported.

## Episode 1 (`ep1`) `metamod.vdf`

Upstream's generic `support/metamod.vdf` writes `"file" "addons/metamod/bin/server"`.
Orange Box+ engines resolve that relative to the mod directory, but Source 2006
(`ep1`) resolves VSP paths relative to `hl2/`, requiring
`"../<mod>/addons/metamod/bin/server"` for any third-party mod. Because
`sourcemod_ep1` already owns `addons/metamod.vdf`, consumers currently stack a
second tar layer to overwrite it (as in `examples/cross/BUILD.bazel`). If more
`ep1` servers appear, a small `mod_dir`-parameterized helper (or splitting the
VDF out of `sourcemod_ep1`) would avoid the extra layer.

## Optional

- **Windows version resources.** Upstream compiles `version.rc` into each binary
  (defining `BINARY_NAME` and `RC_COMPILE`), so file properties and minidumps show
  version information.
- **Crash symbols.** Upstream can generate Breakpad symbols for its binaries.

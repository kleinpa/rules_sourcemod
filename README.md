# rules_sourcemod

Bazel rules for building [SourceMod](https://www.sourcemod.net/) extensions and
plugins with the standard Bazel C++ toolchain — replacing upstream's
AMBuild/Python build, which expects a checked-out SourceMod tree, its git
submodules, and one or more HL2SDKs on disk.

## Usage

`MODULE.bazel`:

```starlark
bazel_dep(name = "rules_sourcemod", version = "1.0.0")
```

`BUILD.bazel`:

```starlark
load("@rules_sourcemod//:defs.bzl", "sourcemod_extension", "sourcemod_plugin")

sourcemod_extension(
    name = "my_extension",
    srcs = ["extension.cpp"],
    hdrs = ["extension.h", "smsdk_config.h"],
    includes = ["."],
)

sourcemod_plugin(
    name = "my_plugin",
    src = "my_plugin.sp",
    includes = ["//my_extension:natives.inc"],
)
```

The extension's code can also live in a plain `cc_library` — preferable when
other targets (tests, tools) need to depend on it without going through the
shared-library link:

```starlark
cc_library(
    name = "core",
    srcs = ["extension.cpp"],
    hdrs = ["extension.h", "smsdk_config.h"],
    includes = ["."],
    deps = ["@sourcemod_sdk//:sourcemod_headers"],
)

sourcemod_extension(
    name = "my_extension",
    deps = [":core"],
)
```

This works with no restated build configuration because
`@sourcemod_sdk//:sourcemod_headers` propagates the platform defines the SDK
needs, and `deps` are linked `alwayslink` so `SMEXT_LINK` and native
registrations survive even though nothing in the shared library references
them directly (SourceMod finds them by symbol after loading). The library must
still export `smsdk_config.h` via `hdrs`/`includes`, since the SDK's
`smsdk_ext.cpp` includes it.

Both rules report their install location via rules_pkg's `PackageFilesInfo`,
so they can be handed straight to rules_pkg's own `pkg_tar`/`pkg_zip` to
assemble a release archive:

```starlark
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

pkg_tar(
    name = "my_addon",
    srcs = [":my_extension", ":my_plugin"],
)
```

```console
$ bazel build --platforms=@rules_sourcemod//platforms:linux_x86_32 //:my_addon
```

The result is a `.tar` containing an `addons/sourcemod/...` tree that
extracts directly into a game server directory.

## Rules

| Rule                  | Produces                           | Installs to                   |
| --------------------- | ---------------------------------- | ----------------------------- |
| `sourcemod_extension` | `<name>.ext.so` / `<name>.ext.dll` | `addons/sourcemod/extensions` |
| `sourcemod_plugin`    | `<name>.smx`                       | `addons/sourcemod/plugins`    |

Each artifact rule reports its install location via rules_pkg's
`PackageFilesInfo`, so archive assembly needs no per-artifact configuration.
The same information is exposed as `SourceModPackageInfo` for consumers that
want to introspect a package without depending on rules_pkg.

## Design

- **Extensions don't need the HL2SDK unless they call engine APIs.** An
  extension that only talks to SourceMod's own interfaces (`IShareSys`,
  `IPlayerHelpers`, ...) is built entirely from the SourceMod SDK sources — no
  vendored binaries, no engine headers. That SDK is fetched as source and
  compiled with the consumer's toolchain, same as everything else. Extensions
  that _do_ need the engine (SourceHook, `edict_t`, netprops) opt in to
  [`//hl2sdk`](hl2sdk/) by naming a branch:

  ```starlark
  hl2sdk = use_extension("@rules_sourcemod//hl2sdk:repositories.bzl", "hl2sdk")
  hl2sdk.branch(name = "css")
  use_repo(hl2sdk, "hl2sdk_css", "metamod_source")
  ```

  Nothing is fetched unless a branch is requested. Requesting one also builds a
  Metamod:Source core for it, which is what makes these rules sufficient to
  assemble a whole game server image, not just an extension binary — see
  [lanofdoom/counterstrikesource-server](https://github.com/lanofdoom/counterstrikesource-server).
  Engine branches are data in the `HL2SDK_BRANCHES` table in
  [`hl2sdk/repositories.bzl`](hl2sdk/repositories.bzl); adding one is a dict
  entry, not a new rule. This is also the one place the build consumes prebuilt
  binaries — Valve ships tier0/vstdlib as binaries only, so `@hl2sdk_<branch>`
  links those `.lib`/`.so` files as-is.

- **Source 2 (`cs2`) is a different shape of SDK, not just another branch.**
  Almost nothing is shared with Source 1 branches: a separate build overlay,
  prebuilt `mathlib`/`interfaces` instead of compiled-from-source, Metamod 2.0
  instead of 1.12, a larger prebuilt-binary footprint (tier0, mathlib,
  interfaces, protobuf, and a `protoc` executable — so codegen only works on
  execution platforms Valve ships a `protoc` for). See the comments in
  [`hl2sdk/repositories.bzl`](hl2sdk/repositories.bzl) before adding another
  Source 2 engine (`dota`, `deadlock`).

- **Everything is pinned by commit SHA.** The build this replaces cloned
  SourceMod at `master` with a `TODO: figure out how to pin this`. Pins now
  live at the top of [`sourcemod/repositories.bzl`](sourcemod/repositories.bzl):
  the SourceMod tag and the exact submodule SHAs it recorded. The compiler and
  the SourcePawn standard library are built from those same sources, so the
  extension and plugin can't drift onto mismatched SourcePawn ABIs.

- **Target architecture is a platform, not a flag.** srcds is 32-bit, so
  extensions must be too. Rather than hardcoding `-m32`, that's expressed as
  `@rules_sourcemod//platforms:linux_x86_32`, which drives toolchain
  resolution properly and makes 64-bit builds (needed by newer engine
  branches) a one-flag change.

- **spcomp is built from source** and registered as a real Bazel toolchain
  (not invoked by path), so a project can substitute its own without forking
  these rules. See [`spcomp/sources.bzl`](spcomp/sources.bzl).

## Reproducibility

Sources are hermetic — every input is pinned and fetched by Bazel, nothing
depends on a system SourceMod/Python/AMBuild install. The toolchain is not,
in three known ways, none patched around (yet):

- **The C++ toolchain is the host's**, so artifacts link against the build
  machine's glibc, not the target's — a correctness problem, not just a
  reproducibility one (see e.g. `GLIBC_2.38` vs. a Debian bookworm target).
  Needs a toolchain with a pinned sysroot (`toolchains_llvm` + a Debian
  sysroot no newer than the deployment target's). Until then, only build on a
  host whose glibc is no newer than the target's.
- **spcomp stamps a build timestamp into every plugin** (`__DATE__`/`__TIME__`
  in `plugins/include/core.inc`, via `localtime()`), so builds a second apart,
  or in different timezones, differ by one byte.
- **`__DATE__` in the C++ sources** (`sourcemod/core/sourcemm_api.cpp`,
  `metamod/core/metamod.h`) gives day-granularity nondeterminism. GCC/Clang do
  honor `SOURCE_DATE_EPOCH` here, but it isn't set by default.

The archive layer itself (rules_pkg) is deterministic, so any difference
between two builds is attributable to one of the above, never to packaging.

## Testing

```console
$ bazel test //...
```

Analysis tests assert the install-layout contract consumers depend on to
assemble their own archives. Tests that pin a non-native platform are tagged
`manual`, grouped under
`//tests:cross_platform_tests`, since they need a C++ toolchain registered for
that platform.

`//tests:game_server_tests` build-tests `//sourcemod:sourcemod_css` end to
end, compiling the whole HL2SDK/Metamod/SourceMod tree against the real
fetched engine SDK. Also tagged `manual`, since it needs network access for a
multi-hundred-megabyte fetch and is slow to compile:

```console
$ bazel test //tests:game_server_tests
```

## Upgrading SourceMod

1. Pick a tag from [alliedmodders/sourcemod](https://github.com/alliedmodders/sourcemod/tags).
2. Read the submodule SHAs that tag records:
   `git ls-tree <tag> public/amtl sourcepawn`
3. Update the pins at the top of
   [`sourcemod/repositories.bzl`](sourcemod/repositories.bzl).
4. Diff the compiler's source lists against upstream's AMBuilder files
   (`compiler/`, `libsmx/`, `vm/`) and update
   [`spcomp/sources.bzl`](spcomp/sources.bzl) if files were added or removed.
5. `bazel test //...`

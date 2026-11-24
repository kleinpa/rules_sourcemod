# Expanding `HL2SDK_BRANCHES` Across All Source 1 Games

## Why Full Branch Coverage Is Cheap

In AMBuild, every configured SDK branch multiplies configuration and build time
unless filtered via `--sdks=...`. In `rules_sourcemod`:

1. **Lazy fetching**: Declaring `hl2sdk_repository(name = "hl2sdk_<branch>")` in
   `extensions.bzl` downloads nothing until a target in `@hl2sdk_<branch>` is
   actually analyzed.
2. **`target_compatible_with` skipping**: Wildcard builds (`bazel build //...`)
   automatically skip branches incompatible with `--platforms` without fetching
   their archives.
3. **Shared engine-independent binaries**: `loader`, `logic`, `sourcepawn.vm`,
   and engine-independent extensions build once per `(os, cpu)` in
   `@sourcemod_sdk`, so each branch preset only compiles `metamod_core_<branch>`,
   `core`, `sdktools`, `sdkhooks`, and any game extension.

## Candidate Branches (`alliedmodders/hl2sdk-manifests`)

From `loader/loader.cpp` and `_SOURCE_ENGINE_CODES` in `hl2sdk/repositories.bzl`,
upstream SourceMod 1.12 supports the following Source 1 branches beyond the
five already wired (`css`, `tf2`, `l4d2`, `sdk2013`, `ep1`):

| Tier | Branch key   | `SE_*` define   | Infix          | Notes / ABI                                                        |
| ---- | ------------ | --------------- | -------------- | ------------------------------------------------------------------ |
| 1    | `hl2dm`      | `HL2DM`         | `2.hl2dm`      | 32-bit & 64-bit (`srcds` 64-bit update, same family as `css`/`tf2`). |
| 1    | `dods`       | `DODS`          | `2.dods`       | 32-bit & 64-bit (`srcds` 64-bit update, same family as `css`/`tf2`). |
| 1    | `csgo`       | `CSGO`          | `2.csgo`       | Legacy CS:GO community servers; needs protobufs + `cstrike/rulesfix.cpp`. |
| 1    | `bms`        | `BMS`           | `2.bms`        | Black Mesa; 32-bit (Linux & Windows).                              |
| 1    | `insurgency` | `INSURGENCY`    | `2.insurgency` | Insurgency (2014); 32-bit (Linux & Windows).                       |
| 1    | `l4d`        | `LEFT4DEAD`     | `2.l4d`        | Left 4 Dead 1; 32-bit (Linux & Windows).                           |
| 2    | `doi`        | `DOI`           | `2.doi`        | Day of Infamy; 32-bit.                                             |
| 2    | `pvkii`      | `PVKII`         | `2.pvkii`      | Pirates, Vikings, and Knights II; 32-bit & 64-bit.                 |
| 2    | `contagion`  | `CONTAGION`     | `2.contagion`  | Contagion; 32-bit.                                                 |
| 2    | `nd`         | `NUCLEARDAWN`   | `2.nd`         | Nuclear Dawn; 32-bit.                                              |
| 3    | `orangebox`  | `ORANGEBOX`     | `2.ep2`        | Older Episode Two mods (`swarm`, `portal2`, `blade`, `bgt`, `eye`, `darkm`, `mcv` rarely see active servers). |

*(Source 2 branches — `cs2`, `dota`, `deadlock` — are excluded by SourceMod 1.x's
own `shouldIncludeSdk` filter.)*

## Per-Branch Quirks to Account For in `hl2sdk.BUILD.bazel`

Most Tier 1 & Tier 2 branches drop straight into `HL2SDK_BRANCHES` as data
entries (commit, sha256, `define`, `extension`, `defines`, and `lib_*` paths),
with two main exceptions:

1. **Protobuf-enabled engines (`csgo`, `blade`, `mcv`)**:
   - Upstream's `SdkHelpers.ambuild` compiles vendored protobuf `.pb.cc` files
     and links prebuilt `libprotobuf.a` / `libprotobuf.lib` from the SDK tree,
     plus `extensions/cstrike` adds `rulesfix.cpp` when `branch == "csgo"`.
   - Keep Tier 1 non-protobuf branches (`hl2dm`, `dods`, `bms`, `insurgency`,
     `l4d`) as a pure table expansion first, then add an optional `protobuf`
     spec key in `hl2sdk.BUILD.bazel` for `csgo`.
2. **Linux `tier0` / `vstdlib` naming variations**:
   - Newer branches use `libtier0_srv.so` / `libvstdlib_srv.so`, whereas some
     older 32-bit branches ship `libtier0.so` / `libvstdlib.so` (without `_srv`)
     or `tier0_i486.so`. Adding optional `tier0_linux_name` / `vstdlib_linux_name`
     fields (defaulting to `libtier0_srv.so` / `libvstdlib_srv.so`) in
     `HL2SDK_BRANCHES` avoids special-casing `hl2sdk.BUILD.bazel`.

## Custom / Forked SDK Override in `extensions.bzl`

Mods on custom SDK2013 forks or unmerged HL2SDK PRs shouldn't have to fork
`rules_sourcemod` to test a different commit. Add a `sourcemod.hl2sdk(...)` tag
class to `extensions.bzl` (root module only) allowing commit/sha256 overrides on
any branch in `HL2SDK_BRANCHES`.

# Remaining Source 1 HL2SDK Branches

`HL2SDK_BRANCHES` covers `css`, `tf2`, `hl2dm`, `dods`, `l4d2`, `sdk2013`, and
`ep1`. Platforms and libraries below come from
[hl2sdk-manifests](https://github.com/alliedmodders/hl2sdk-manifests) at
`fbc3a11`. Source 2 branches (`cs2`, `dota`, `deadlock`) are out of scope;
SourceMod 1.x excludes them.

## Cost

- **Unused branches are free.** A branch is fetched only when one of its targets
  is analyzed, and `//...` skips branches the target platform cannot run.
- **Used branches are cheap.** Engine-independent binaries are shared, so each
  branch compiles only `tier1`, `mathlib`, the Metamod core, SourceMod core,
  `sdktools`, `sdkhooks`, and any game extension.

## Candidates

Priority is a rough estimate of demand.

| Priority | Branch        | `define`      | Infix          | Windows  | Linux    | Extra work                              |
| -------- | ------------- | ------------- | -------------- | -------- | -------- | --------------------------------------- |
| 1        | `bms`         | `BMS`         | `2.bms`        | x86      | x86      | None                                    |
| 1        | `l4d`         | `LEFT4DEAD`   | `2.l4d`        | x86      | x86      | Library names                           |
| 1        | `insurgency`  | `INSURGENCY`  | `2.insurgency` | x86, x64 | x86      | Platform constraints, `interfaces`      |
| 1        | `csgo`        | `CSGO`        | `2.csgo`       | x86      | x86, x64 | All of the below                        |
| 2        | `nucleardawn` | `NUCLEARDAWN` | `2.nd`         | x86      | x86      | None                                    |
| 2        | `contagion`   | `CONTAGION`   | `2.contagion`  | x86      | -        | None                                    |
| 2        | `pvkii`       | `PVKII`       | `2.pvkii`      | x86, x64 | x86, x64 | Library names                           |
| 2        | `doi`         | `DOI`         | `2.doi`        | x86, x64 | x86      | Platform constraints, `interfaces`      |
| 3        | `orangebox`   | `ORANGEBOX`   | `2.ep2`        | x86      | x86      | Library names                           |

Other branches are low priority: `swarm`, `bgt`, `eye`, and `darkm` (Windows x86
only), `blade` and `mcv` (protobuf), and `portal2` (its manifest lists no
platforms).

## Extra work

- **Library names.** `hl2sdk.BUILD.bazel` expects `libtier0_srv.so` and
  `libvstdlib_srv.so` on Linux. `l4d` and `pvkii` use `libtier0.so`, `orangebox`
  uses `tier0_i486.so`, and `csgo` uses `libtier0.so` on x86 and
  `libtier0_client.so` on x64; `vstdlib` follows the same pattern. Add optional
  per-architecture name fields to `HL2SDK_BRANCHES`.
- **Platform constraints.** `branch_target_compatible_with` assumes Windows and
  Linux support the same architectures. With 64-bit libraries on only one OS, it
  would accept 64-bit on both and link the wrong libraries.
- **`interfaces`.** Upstream links a prebuilt `interfaces` library, which
  `hl2sdk.BUILD.bazel` does not provide.
- **`csgo` only.** SourceMod core compiles `smn_protobuf.cpp` and the SDK's
  `.pb.cc` files and links a prebuilt `libprotobuf` (see `core/AMBuilder`; `blade`
  and `mcv` also need this). `extensions/cstrike` adds `rulesfix.cpp` and links
  `steam_api`. The manifest sets `_GLIBCXX_USE_CXX11_ABI=0`.

Only `pvkii` has an upstream `tier1/AMBuilder`. The others link prebuilt `tier1`
and `mathlib` upstream, so compiling those from source may need patches, as it
did for `ep1`.

## Adding a branch

1. Add the entry to `HL2SDK_BRANCHES` in `hl2sdk/repositories.bzl`.
2. Add `hl2sdk_<branch>` to `use_repo` in `MODULE.bazel`.
3. Add the alias in `hl2sdk/BUILD.bazel` and `metamod_core` in
   `hl2sdk/metamod.BUILD.bazel`.
4. Add the preset in `sourcemod/BUILD.bazel` (and `_GAME_EXTENSIONS` in
   `sourcemod/server.bzl` for `csgo`) and a build test in `tests/BUILD.bazel`.
5. Update the branch lists in `README.md`, `docs/design.md`, and the
   `sourcemod_extension` docs.

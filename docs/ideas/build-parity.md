# Upstream SourceMod Build Parity

## 1. Remaining Upstream Extensions

Comparing `sourcemod/sdk.BUILD.bazel` against upstream's root `AMBuildScript`
(lines 673–687), the remaining unbundled official extensions are:

| Extension        | Output stem      | Upstream sources & dependencies                                                      | Notes                                                                                                                               |
| ---------------- | ---------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| `dhooks`         | `dhooks.ext`     | `extensions/dhooks/**` + `CDetour` + `safetyhook` + `sourcepawn/vm`                  | Win32, Win64, and Linux32 in SM 1.12 (`AMBuilder` skips Linux64 in 1.12; added in 1.13).                                            |
| `curl`           | `webternet.ext`  | `extensions/curl/*.cpp` + vendored `extensions/curl/curl-src/lib` (`CURL_STATICLIB`) | Required by `updater.ext`.                                                                                                          |
| `updater`        | `updater.ext`    | `extensions/updater/*.cpp`                                                           | Auto-updates `gamedata/` on boot unless `DisableAutoUpdate` is `"yes"` in `core.cfg` — keep opt-in rather than bundled in OCI images. |
| `pgsql`          | `dbi.pgsql.ext`  | `extensions/pgsql/**` + in-tree prebuilt `libpq.a` / `libpq.lib`                     | Self-contained; opt-in target.                                                                                                      |
| `mysql` *(ext.)* | `dbi.mysql.ext`  | `extensions/mysql/**` + external `libmysqlclient` / MariaDB Connector-C              | Only upstream extension without in-tree deps; opt-in target.                                                                        |

## 2. Linux Runtime & Symbol Isolation Flags on Server/Metamod `.so`s

Auditing `private/flags.bzl`, `sourcemod/server.bzl`, and `hl2sdk/metamod.bzl`
against upstream's `configure_gcc`:

- `private/extension.bzl` passes `-static-libstdc++`, `-static-libgcc`,
  `-Wl,--exclude-libs,ALL`, `-fvisibility=hidden`, and
  `-fvisibility-inlines-hidden`, whereas `SERVER_COPTS` / `SERVER_LINKOPTS` and
  `metamod.bzl` omit them (and `sdk.BUILD.bazel` omits
  `public/amtl/compat/stdcxx.cpp`).
- Applying the same isolation flags across all server and Metamod `.so`s avoids
  `GLIBCXX_*` load errors against Valve's older Steam Runtime `libstdc++.so.6`
  and prevents `tier1` / `mathlib` symbol interposition inside `srcds` (verify
  on Linux CI with `symbol_closure_test`).

## Optional: Windows `.rc` Version Resources & Debug Symbol Splitting

- **`version.rc` embedding on Windows**: Upstream compiles `version.rc` (with
  `/DBINARY_NAME="..."` and `/DRC_COMPILE`) into every `.dll` and `.exe` via
  `rc.exe` / `llvm-rc` so Windows File Properties and minidumps record product
  and version strings.
- **Breakpad / detached debug symbols**: Upstream optionally strips release
  `.so`s and exports `.pdb` / `.sym` bundles for crash symbolication.

# Reducing `/patches`

`patches/` carries **10 `.patch` files** across three external trees
(`@sourcemod_sdk`, `@metamod_source`, and `@hl2sdk_ep1`), plus `.gitattributes`
(`*.patch -text`) to keep `repository_ctx.patch` happy against upstream CRLF
files (`@sourcemod_curl` needs zero patches because `sourcemod/curl.BUILD.bazel`
defines `HEADER_CURL_CONFIG_WIN32_H` and passes Windows `HAVE_*` flags directly).

## Inventory & Disposition

| Patch(es) | Target repo | What it does | Why it isn't just a flag | Verdict |
| --- | --- | --- | --- | --- |
| `sourcemod-build-date-api.patch`<br>`sourcemod-build-date-version.patch`<br>`metamod-build-date-header.patch`<br>`metamod-build-date-version.patch` | `@sourcemod_sdk`<br>`@metamod_source` | Replaces `__DATE__` / `__TIME__` with `"Jan  1 1980"` / `"00:00:00"` | `//linux` Clang already redacts `__DATE__`, and `clang-cl` honors `SOURCE_DATE_EPOCH`, **but** native Windows `cl.exe` (`@local_config_cc`) ignores both `/D__DATE__` (`C4117`) and `SOURCE_DATE_EPOCH` | **Keep** while native `cl.exe` reproducibility matters (or upstream `#ifndef` guards) |
| `hl2sdk-ep1-memalloc-include.patch` | `@hl2sdk_ep1` | Adds `#include "tier0/commonmacros.h"` to `public/tier0/memalloc.h` | `cc_library` `copts` (`/FI`) do not propagate transitively to downstream `sourcemod_ep1_core` / `metamod_core_ep1` targets | **Upstream** to `alliedmodders/hl2sdk` `episode1`; until then keep (1-line patch beats scattering `/FI` across rdeps) |
| `hl2sdk-ep1-mathlib-base-clang.patch` | `@hl2sdk_ep1` | Guards AMD 3DNow! `_asm`, naked `VectorMA`, `0x80000000` narrowing, and `clamp(t, 0, 1)` in `mathlib_base.cpp` | Could be avoided only by importing `ep1`'s prebuilt `lib/public/mathlib.lib` instead of compiling `mathlib` from source | **Optional drop** (source vs prebuilt `.lib` trade-off) |
| `hl2sdk-ep1-ssemath-clang.patch`<br>`hl2sdk-ep1-movzx-operand-size.patch` | `@hl2sdk_ep1` | Fixes `__m128.m128_f32` union access under `clang-cl`, and an invalid `movzx` operand size, in public EP1 math headers | Live in public headers; `alliedmodders/hl2sdk` `episode1` rarely changes, so bitrot cost is low | **Upstream** to `alliedmodders/hl2sdk` `episode1` |
| `spcomp-source-date-epoch.patch` | `@sourcemod_sdk` (`sourcepawn`) | Honors `SOURCE_DATE_EPOCH` in `spcomp` instead of `time()` / `localtime()` | Link-time clock shims are more magic than a 9-line diff | **Drop** once 1.12 has it: merged to `master`, so ask for a `1.12-dev` backport |
| `metamod-clang-thiscall-thunk.patch` | `@metamod_source` | Teaches SourceHook's Win32 x86 byte-scanner to decode `clang-cl` vtable thunks | Genuine `clang-cl` vs `cl.exe` codegen difference | **Keep**, and port to KHook for Metamod 2.0 (see [sourcemod-1.13.md](sourcemod-1.13.md#khook)) |

## Takeaways

- **Why the 4 build-date patches stay**: Real `cl.exe` emits
  `C4117: macro name '__DATE__' is reserved, '#define' ignored` even under
  `/wd4117`, and ignores `SOURCE_DATE_EPOCH` (`/Brepro` only zeroes PE header
  timestamps). `//linux` already passes `-D__DATE__="redacted"`, and setting
  `SOURCE_DATE_EPOCH=315532800` in `//windows` (`clang-cl`) would cover
  cross-builds, **but** native `cl.exe` builds still rely on the 4 patches (or
  upstreaming `#ifndef SM_BUILD_TIMESTAMP` / `MMS_BUILD_TIMESTAMP` guards).
- **Cleanest path toward zero patches**: upstream the first two groups below.
  That leaves the `mathlib_base` and thunk patches.

## Upstreamable

Checked against upstream on 2026-11-25.

Uncontroversial:

- `spcomp-source-date-epoch.patch`: already merged to SourcePawn `master`
  ([#1204](https://github.com/alliedmodders/sourcepawn/pull/1204)) but not
  `1.12-dev`. Only a backport is needed, and upstream's version can replace ours.
- `hl2sdk-ep1-memalloc-include.patch`: adds a missing include.
- `hl2sdk-ep1-movzx-operand-size.patch`: fixes invalid assembly.
- `hl2sdk-ep1-ssemath-clang.patch`: leaves MSVC and Linux unchanged apart from a
  cast. `episode1` already takes fixes like it (latest commit: "Compatibility
  fixes for Clang 22").

Probably fine, but not as written:

- The four build-date patches hard-code a date. Upstream would need `#ifndef`
  guards around `SM_BUILD_TIMESTAMP`, `MMS_BUILD_TIMESTAMP`, and
  `SOURCEMM_DATE`, and a similar override for `GetDate()`.

Likely to be contested:

- `hl2sdk-ep1-mathlib-base-clang.patch`: replaces several math routines under
  Clang. The casts and `clamp` fixes could be split out and sent alone.
- `metamod-clang-thiscall-thunk.patch`: adds machine-code matching for a compiler
  upstream doesn't build with. Metamod `master` has replaced SourceHook with
  [KHook](https://github.com/Kenzzer/KHook), which doesn't recognize Clang's
  32-bit thunks either. KHook is the better place to send a fix, but it would be
  a rewrite of this patch.

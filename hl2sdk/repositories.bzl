"""Repository rules that fetch the HL2SDK and Metamod:Source.

These replace the `git clone hl2sdk-manifests` + `configure.py --hl2sdk-root`
dance in upstream's build.sh. As with the SourceMod SDK, everything is pinned
and fetched through Bazel's downloader.

Unlike @sourcemod_sdk, the HL2SDK is *not* pure source: Valve ships tier0 and
vstdlib as prebuilt binaries only (the tree has a tier0_exclude.vpc and no
tier0 sources). Those binaries are consumed as-is; see hl2sdk.BUILD.bazel.
"""

def _apply_patch(repository_ctx, patch_label):
    """Applies one patch via the host `patch` binary, not repository_ctx.patch().

    repository_ctx.patch() (Bazel's own, portable patch parser) silently
    mis-locates hunks past the first in a single multi-hunk patch against a
    large file -- confirmed against mathlib/mathlib_base.cpp's compat
    patch (see the "ep1 only" comment in _hl2sdk_impl below): the first
    hunk lands, later ones don't, with no error raised either way. The
    same patch applies cleanly with GNU patch (`patch -p1 --dry-run`)
    against the same tree, so this shells out to that instead. Costs
    portability -- a `patch` binary has to be on the host's PATH -- but
    this whole cross-compiling setup already assumes a Linux-like host
    (see windows/xwin_sysroot.bzl), so that's not a new requirement.
    """
    result = repository_ctx.execute(["patch", "-p1", "--fuzz=0", "-i", repository_ctx.path(patch_label)])
    if result.return_code != 0:
        fail("applying {} failed:\n{}\n{}".format(patch_label, result.stdout, result.stderr))

# alliedmodders/metamod-source, branch 1.12-dev. Supplies SourceHook and the
# ISmmAPI/ISmmPlugin headers; a Metamod extension cannot be compiled without
# it.
#
# amtl is a git submodule of metamod-source at third_party/amtl. GitHub's
# archive tarballs never carry submodule contents -- the directory is present
# but empty -- so it is fetched separately and laid down at the path the sources
# expect. Metamod's core needs it (`#include <amtl/am-string.h>`), so without
# this the core does not compile.
#
# _METAMOD_AMTL_COMMIT is Metamod's own pin, read from the gitlink at
# _METAMOD_COMMIT (`git ls-tree <commit> third_party/amtl`). It is NOT the
# same commit SourceMod pins for its own copy of amtl; the two trees track it
# independently, so this must be re-read when bumping the commit rather than
# copied from //sourcemod:repositories.bzl.
_METAMOD_COMMIT = "afc8233eedcd0c832b411c1da852328328db5c50"
_METAMOD_AMTL_COMMIT = "285b4f853c0003023838140113e3ec066bd800c6"

# Engine branches of alliedmodders/hl2sdk. Everything is pinned by commit SHA,
# never a moving branch -- these are living branches that Valve's SDK drops land
# on, so `css` at two different times is two different SDKs.
#
#   commit: branch head, pinned.
#   code:   the SOURCE_ENGINE value. Taken from the engine's manifest; the SDK
#           headers and Metamod both switch on it, and the SE_* defines below
#           are built from the whole set so `#if SOURCE_ENGINE == SE_CSS` works.
#   define: the SE_* suffix, again from the manifest.
#   extension: the backend suffix the Metamod loader dlopens, i.e. the
#           `metamod.<extension>.so` filename. From the manifest.
#   defines/include_paths: copied from the manifest for that branch.
#   lib_linux_x86_32/lib_linux_x86_64/lib_windows_x86_32/lib_windows_x86_64:
#           directories holding the prebuilt tier0/vstdlib binaries, again
#           copied from the manifest's `dynamic_libs`/`libs` entries for that
#           (os, arch). These are NOT the same shape across branches -- css and
#           tf2 use lib/public/linux(64) and lib/public/x86 (x64), l4d2 uses
#           lib/linux (no "public") and a flat lib/public with no per-arch
#           subdirectory on Windows, sdk2013 uses lib/public/linux32 -- so they
#           are branch data too, not a hardcoded path in hl2sdk.BUILD.bazel.
#           A branch with no 64-bit SDK (l4d2, sdk2013) omits the two
#           lib_*_x86_64 keys; _hl2sdk_impl falls back to the 32-bit
#           directory, which is never actually selected since there is no
#           64-bit platform to build those branches for.
#
# The metadata mirrors the corresponding manifests/*.json in
# alliedmodders/hl2sdk-manifests, which is what upstream AMBuild reads. Adding
# a branch is an entry here, not new code.
HL2SDK_BRANCHES = {
    "css": {
        "commit": "d0ddd91faed91af581c06df28354156ae31b0bdb",
        "code": 6,
        "define": "CSS",
        "extension": "2.css",
        "defines": ["CSTRIKE_DLL"],
        "posix_defines": ["NO_HOOK_MALLOC", "NO_MALLOC_OVERRIDE"],
        "include_paths": [
            "public",
            "public/engine",
            "public/mathlib",
            "public/vstdlib",
            "public/tier0",
            "public/tier1",
            "public/toolframework",
            "public/game/server",
            "game/shared",
            "common",
        ],
        "lib_linux_x86_32": "lib/public/linux",
        "lib_linux_x86_64": "lib/public/linux64",
        "lib_windows_x86_32": "lib/public/x86",
        "lib_windows_x86_64": "lib/public/x64",
    },
    "tf2": {
        "commit": "73ecbbe946955a70409bcf7ee4ddf1105ad4231b",
        "code": 12,
        "define": "TF2",
        "extension": "2.tf2",
        "defines": ["TF_DLL"],
        "posix_defines": ["NO_HOOK_MALLOC", "NO_MALLOC_OVERRIDE"],
        "include_paths": [
            "public",
            "public/engine",
            "public/mathlib",
            "public/vstdlib",
            "public/tier0",
            "public/tier1",
            "public/toolframework",
            "public/game/server",
            "game/shared",
            "common",
        ],
        "lib_linux_x86_32": "lib/public/linux",
        "lib_linux_x86_64": "lib/public/linux64",
        "lib_windows_x86_32": "lib/public/x86",
        "lib_windows_x86_64": "lib/public/x64",
    },
    # 32-bit only -- the manifest lists no x86_64 platform for either OS, and
    # its library directories don't have the "public" component css/tf2 use.
    "l4d2": {
        "commit": "2a31cd007b2d7d2f964dc093eedcf7a812cf9dd6",
        "code": 16,
        "define": "LEFT4DEAD2",
        "extension": "2.l4d2",
        "defines": [],
        "posix_defines": ["NO_HOOK_MALLOC", "NO_MALLOC_OVERRIDE"],
        "include_paths": [
            "public",
            "public/engine",
            "public/mathlib",
            "public/vstdlib",
            "public/tier0",
            "public/tier1",
            "public/toolframework",
            "public/game/server",
            "game/shared",
            "common",
        ],
        "lib_linux_x86_32": "lib/linux",
        "lib_windows_x86_32": "lib/public",
    },
    # The generic Source SDK 2013 base a number of independent mods build
    # against, rather than a single game's own branch -- one hl2sdk_repository
    # built from this entry can back a sourcemod_game_server for any SDK2013
    # mod, since none of them get a dedicated per-game SourceMod extension
    # (see _GAME_EXTENSIONS in //sourcemod:server.bzl). 32-bit only, same as
    # l4d2, and with the same flattened library directories.
    "sdk2013": {
        "commit": "4c56ee5bc8bfe00793abb7d40eb3f6fb040f10d2",
        "code": 9,
        "define": "SDK2013",
        "extension": "2.sdk2013",
        "defines": [],
        "posix_defines": ["NO_HOOK_MALLOC", "NO_MALLOC_OVERRIDE"],
        "include_paths": [
            "public",
            "public/engine",
            "public/mathlib",
            "public/vstdlib",
            "public/tier0",
            "public/tier1",
            "public/toolframework",
            "public/game/server",
            "game/shared",
            "common",
        ],
        "lib_linux_x86_32": "lib/public/linux32",
        "lib_windows_x86_32": "lib/public",
    },
    # The original (pre-Orange Box) Source engine -- what The Hidden: Source,
    # among other 2004-2006 mods, still runs on. 32-bit only, same as l4d2/
    # sdk2013 (the manifest lists no x86_64 platform at all for this branch),
    # and with the same flattened Windows library directory.
    #
    # Unlike every other branch here, this manifest's `include_paths` has no
    # "common" entry and uses "public/dlls" + "game_shared" (no slash) where
    # newer branches use "public/game/server" + "game/shared" -- this is an
    # older tree layout, not a typo; see hl2sdk_game_server in
    # hl2sdk.BUILD.bazel, which globs "game/server" unconditionally and so
    # simply finds nothing for this branch (fine: no branch this old gets a
    # per-game SourceMod extension -- see _GAME_EXTENSIONS in
    # //sourcemod:server.bzl -- so nothing needs those headers).
    #
    # The manifest also lists no top-level "defines"/"posix_defines" for this
    # branch at all (unlike css/tf2/l4d2/sdk2013, which all set
    # NO_HOOK_MALLOC/NO_MALLOC_OVERRIDE) -- left empty here to match rather
    # than assumed.
    #
    # Linux is unwired, not absent: the manifest's linux libs live under a
    # "linux_sdk/" directory with a "tier0_i486.so"/"vstdlib_i486.so" naming
    # scheme neither hl2sdk.BUILD.bazel's cc_import paths (which expect
    # "lib<name>_srv.so" the way every other branch ships it) nor its
    # directory convention match, so wiring it up for real would need
    # overlay changes this repo has no branch that needs yet -- The Hidden
    # only ships a Windows dedicated server. "linux_sdk" below is still the
    # real directory (so the generated cc_import labels stay valid Starlark,
    # which is checked eagerly at package load regardless of which
    # cc_import a build actually selects) -- it just doesn't contain files
    # under the names this overlay looks for, so building //hl2sdk:hl2sdk_ep1
    # (or anything depending on it) for a linux_x86_* platform will fail at
    # the missing-file stage. windows_x86_32 is the only target this branch
    # is actually wired for.
    "ep1": {
        "commit": "4b0cde271be6806b95842e78348009712a8b3fbe",
        "code": 1,
        "define": "EPISODEONE",
        "extension": "2.ep1",
        "defines": [],
        "posix_defines": [],
        "include_paths": [
            "public",
            "public/engine",
            "public/mathlib",
            "public/vstdlib",
            "public/tier0",
            "public/tier1",
            "public/toolframework",
            "public/dlls",
            "game_shared",
        ],
        "lib_linux_x86_32": "linux_sdk",
        "lib_windows_x86_32": "lib/public",
    },
}

# `SOURCE_ENGINE` is compared against `SE_<NAME>` constants, and the SDK headers
# reference branches other than the one being built. Upstream defines the whole
# table for every build; this reproduces that.
#
# The full upstream table is larger than HL2SDK_BRANCHES -- these are the codes
# for every engine AMBuild knows about, needed so that a `#if SOURCE_ENGINE ==
# SE_TF2` in a header does not fail to compile against an undefined symbol.
#
# Transcribed from the `define`/`code` pairs in every manifests/*.json in
# alliedmodders/hl2sdk-manifests. The values are positional and have been
# renumbered upstream before, so re-read them when bumping _METAMOD_COMMIT
# rather than assuming they are stable.
_SOURCE_ENGINE_CODES = {
    "EPISODEONE": 1,
    "DARKMESSIAH": 2,
    "ORANGEBOX": 3,
    "BLOODYGOODTIME": 4,
    "EYE": 5,
    "CSS": 6,
    "HL2DM": 7,
    "DODS": 8,
    "SDK2013": 9,
    "PVKII": 10,
    "BMS": 11,
    "TF2": 12,
    "LEFT4DEAD": 13,
    "NUCLEARDAWN": 14,
    "CONTAGION": 15,
    "LEFT4DEAD2": 16,
    "ALIENSWARM": 17,
    "PORTAL2": 18,
    "BLADE": 19,
    "INSURGENCY": 20,
    "DOI": 21,
    "MCV": 22,
    "CSGO": 23,
    "DOTA": 24,
    "CS2": 25,
    "MOCK": 26,
    "DEADLOCK": 27,
}

def _metamod_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/metamod-source/archive/{}.tar.gz".format(
            _METAMOD_COMMIT,
        ),
        stripPrefix = "metamod-source-" + _METAMOD_COMMIT,
    )

    # The amtl submodule, laid down where the sources `#include <amtl/...>`
    # from. See the comment on _METAMOD_COMMIT.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/amtl/archive/{}.tar.gz".format(
            _METAMOD_AMTL_COMMIT,
        ),
        output = "third_party/amtl",
        stripPrefix = "amtl-" + _METAMOD_AMTL_COMMIT,
    )

    # sh_memfuncinfo.h's SourceHook::GetFuncInfo introspects a pointer-to-
    # member-function by pattern-matching the machine code of the compiler-
    # generated thiscall thunk `&Class::VirtualMethod` produces, since
    # MSVC's ABI (unlike Itanium's) doesn't encode the vtable index directly
    # in the pointer's own bytes. Its patterns only recognize the compact,
    # 2-to-3-instruction thunk shape real MSVC and GCC emit (`mov eax,[ecx];
    # jmp [eax+off]`, plus a vararg variant) -- clang-cl (this project's
    # cross-compiling toolchain; see windows/xwin_sysroot.bzl) instead keeps
    # a full stack frame and loads the vtable slot into eax *before* the
    # tail jmp, a longer shape none of the existing patterns match at any
    # optimization level tried (confirmed at both fastbuild and -c opt).
    # Unmatched falls through to `isVirtual = false`, not an error -- every
    # GetFuncInfo call on a simple no-argument virtual (IServerGameDLL::
    # GameInit, for one) silently returns a bogus vtblindex instead of
    # failing loudly, and every SH_MANUALHOOK_RECONFIGURE built from it
    # corrupts the hook it configures. Unlike the ep1-only patches below,
    # this is a general clang-cl/SourceHook incompatibility with no
    # engine-branch condition -- applied whenever Metamod is fetched at
    # all, the same as the amtl submodule fetch just above.
    _apply_patch(repository_ctx, repository_ctx.attr._clang_thiscall_thunk_patch)

    # loader/serverplugin.cpp's vtable surgery for ClientFullyConnect (added
    # to the vtable by Alien Swarm, so every newer engine's vtable already
    # has room for it and every older one needs its later entries shifted up
    # by one slot to make room) excludes AlienSwarm/Portal2/Blade/Insurgency/
    # DOI/CSGO/MCV/DOTA from that shift, correctly, but not Episode1 -- an
    # older engine with the same "no ClientFullyConnect slot yet" vtable
    # shape as the rest of that list, just missing from it. Left as-is, ep1's
    # ClientFullyConnect is misdetected as non-virtual (it resolves to
    # whatever landed in the *shifted* slot instead) and trips
    # `assert(mfp_fconnect.isVirtual)` at startup. A companion block just
    # above this one (not patched) already gets ep1 right, excluding it by
    # name alongside DarkMessiah -- this is the same fix applied to the block
    # upstream missed it in. Scoped to ep1 being requested at all, same as
    # the HL2SDK patches above, since it's dead code for every branch this
    # module doesn't build for.
    if "ep1" in repository_ctx.attr.branches:
        _apply_patch(repository_ctx, repository_ctx.attr._ep1_serverplugin_vtable_patch)

    # One core is built per requested engine branch, so the overlay is a
    # template: the branch list arrives as data and //hl2sdk:metamod_cores.bzl
    # turns it into targets. Hardcoding a branch here would make @metamod_source
    # reference an @hl2sdk_<branch> repository that the extension may not have
    # been asked to create.
    cores = [
        {
            "branch": branch,
            "extension": HL2SDK_BRANCHES[branch]["extension"],
        }
        for branch in repository_ctx.attr.branches
    ]

    repository_ctx.template(
        "BUILD.bazel",
        repository_ctx.attr._build_file,
        # str() rather than json.encode(): the substitution is read back as
        # Starlark, and JSON spells booleans `true`/`false`.
        substitutions = {"%{cores}": str(cores)},
        executable = False,
    )

metamod_repository = repository_rule(
    implementation = _metamod_impl,
    doc = "Fetches Metamod:Source (SourceHook + the ISmmAPI headers).",
    attrs = {
        "branches": attr.string_list(
            doc = "Engine branches to build a Metamod core for.",
            mandatory = True,
        ),
        "_build_file": attr.label(
            default = Label("//hl2sdk:metamod.BUILD.bazel"),
            allow_single_file = True,
        ),
        "_ep1_serverplugin_vtable_patch": attr.label(
            default = Label("//patches:metamod-ep1-clientfullyconnect-vtable.patch"),
            allow_single_file = True,
        ),
        "_clang_thiscall_thunk_patch": attr.label(
            default = Label("//patches:metamod-clang-thiscall-thunk.patch"),
            allow_single_file = True,
        ),
    },
)

def _hl2sdk_impl(repository_ctx):
    branch = repository_ctx.attr.branch
    spec = HL2SDK_BRANCHES[branch]

    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/hl2sdk/archive/{}.tar.gz".format(
            spec["commit"],
        ),
        stripPrefix = "hl2sdk-" + spec["commit"],
    )

    # ep1 only: source-level incompatibilities with a strict/modern compiler
    # that the pinned commit's own tree never had to satisfy (it predates
    # AMBuild; there's no per-branch AMBuilder to compare against, just what
    # actually fails to build). All are things a native MSVC cl.exe -- what
    # this code was actually written and tested against -- tolerated
    # silently:
    #
    # 1. public/mathlib/math_base.h's Float2Int/Floor2Int/Ceil2Int use
    #    MSVC-dialect inline asm to set the FPU rounding mode, ending with
    #    `movzx eax, CtrlwdHolder` -- moving the (16-bit) FPU control word
    #    fnstcw just wrote into eax, zero-extended. CtrlwdHolder is declared
    #    `int` (its low 16 bits are the only ones fnstcw ever touches; the
    #    rest is uninitialized stack garbage), so the instruction's true
    #    source size doesn't match its C-declared one. Clang's inline-asm
    #    parser (used both by a native clang-cl and this module's
    #    cross-compiling one, see windows/xwin_sysroot.bzl) won't guess,
    #    and errors "ambiguous operand size for instruction 'movzx'". The
    #    patch adds the `word ptr` real MSVC inferred implicitly, which is
    #    what the code always meant.
    #
    # 2. public/tier0/memalloc.h calls IsPowerOfTwo() (tier0/commonmacros.h)
    #    without including that header -- every translation unit that
    #    happened to pull commonmacros.h in first via some other path (e.g.
    #    tier0/dbg.h, which includes basetypes.h, which includes it) never
    #    noticed. tier1/mempool.cpp doesn't: it includes tier1/mempool.h,
    #    which includes tier0/memalloc.h before anything that would supply
    #    the declaration, so the *first* header in the chain to actually use
    #    IsPowerOfTwo is the one missing its own dependency. Neither of
    #    these repeats in newer branches (later HL2SDK snapshots replaced
    #    the asm with intrinsics and, separately, happen to route through a
    #    path that pulls commonmacros.h in sooner).
    #
    # 3. public/mathlib/ssemath.h's SSEVec4/X()/Y()/Z() read __m128 lanes via
    #    `.m128_f32[idx]`, an MSVC-only member of the <xmmintrin.h> __m128
    #    definition (a union, in MSVC's own CRT headers) -- gated on
    #    `#ifdef _LINUX`/`#else`, i.e. "assume any non-Linux build is real
    #    MSVC". A native clang-cl or this module's cross-compiling one both
    #    use LLVM's own <xmmintrin.h>, where __m128 is a plain vector
    #    builtin with no such member, so `.m128_f32` fails to parse there
    #    even while targeting Windows. The file already carries a working,
    #    portable fallback for exactly this case (an `l_m128` union cast,
    #    behind the `_LINUX` branch) -- the patch just widens that branch's
    #    condition to "not real MSVC" (`!_MSC_VER || __clang__`) instead of
    #    "not Windows", so Clang takes it regardless of target OS.
    #
    #    Same file, same patch: fnegate()'s `int32 signmask[4] =
    #    {0x80000000, ...}` list-initializes a *signed* array with a value
    #    one past INT32_MAX. GCC/MSVC narrow it silently; Clang treats
    #    narrowing a compile-time constant in a braced-init-list as
    #    ill-formed, which -Wno-c++11-narrowing (sourcemod/warnings.bzl)
    #    can't waive -- unlike the plain deprecation warnings that flag
    #    covers, this one is a language rule, not a diagnostic opt-out. An
    #    explicit `(int32)` cast on each element sidesteps the rule (a cast
    #    is exempt) without changing the bit pattern.
    #
    # 4. mathlib/mathlib_base.cpp has the same constant-narrowing problem
    #    once more (`_PS_EXTERN_CONST_TYPE(am_sign_mask, int32,
    #    0x80000000)`, a macro expanding to the same kind of braced-init as
    #    #3) -- same `(int32)` cast fix, at the macro's call site rather
    #    than its definition, since every *other* call site's constant
    #    already fits. It also has three `_declspec(naked)` functions
    #    (VectorMA's two overloads, plus a dead/`Assert(0)`-guarded
    #    `_SSE_VectorMA`) that open with an `Assert(...)` call before their
    #    all-asm body: a naked function is a contract that its body is
    #    *only* inline asm (the compiler emits no prologue/epilogue, so
    #    there's no stack frame for a real function call to use), which
    #    MSVC never enforced but Clang does. VectorMA's two overloads
    #    already carry a working portable C++ fallback in their own
    #    `#else`; the patch just widens the `#if _WIN32` guard picking
    #    between them to also exclude Clang, the same `!_MSC_VER ||
    #    __clang__` shape as #3. `_SSE_VectorMA` has no such fallback and
    #    nothing calls it (it's dead code, upstream's own FIXME says so) --
    #    the patch excludes its body outright under Clang rather than
    #    inventing a replacement for code that was never meant to run.
    #
    #    Same file, two more calls to `clamp(t, 0, 1)` where `t` is `float`
    #    -- basetypes.h's `clamp` is `template<class T> T clamp(T const&,
    #    T const&, T const&)`, one T for all three by-reference parameters,
    #    so deducing T=float from `t` and T=int from the literals is a
    #    genuine conflict, not merely a narrowing warning. Old MSVC's
    #    template deduction was permissive enough to accept it anyway;
    #    Clang's isn't. Spelling the literals `0.0f, 1.0f` makes every
    #    argument's type agree, with no change in the value clamped to.
    #
    #    Also same file: the three `_3DNow_*` functions (Sqrt,
    #    VectorNormalize, InvRSquared) are hand-written AMD 3DNow! asm
    #    (`femms`, `PFRSQRT`, ...) -- a CPU feature line that AMD itself
    #    retired around 2010, so MathLib_Init() (near the bottom of this
    #    file) never actually selects these on any CPU this build could
    #    run on; nothing exercises them. Clang's MASM parser doesn't
    #    recognize the mnemonics at all, which is a parse error, not a
    #    warning, so there's no flag to wave this one away with either.
    #    Each has an exact-signature, already-portable equivalent earlier
    #    in the same file (_VectorNormalize, _InvRSquared, or plain
    #    sqrtf()) written for the no-SIMD-available fallback case -- the
    #    patch delegates to those under Clang instead of hand-assembling a
    #    replacement for a code path nothing reaches.
    #
    # None of these repeat in newer branches (later HL2SDK snapshots
    # replaced the inline asm, the SSE union access, and the naked
    # functions with intrinsics, and happen to route through a path that
    # pulls commonmacros.h in sooner), so all these patches are scoped to
    # ep1 alone. See _apply_patch's own docstring for why these go through
    # the host `patch` binary rather than repository_ctx.patch().
    if branch == "ep1":
        _apply_patch(repository_ctx, repository_ctx.attr._ep1_movzx_patch)
        _apply_patch(repository_ctx, repository_ctx.attr._ep1_memalloc_patch)
        _apply_patch(repository_ctx, repository_ctx.attr._ep1_ssemath_patch)
        _apply_patch(repository_ctx, repository_ctx.attr._ep1_mathlib_base_patch)

    # The SDK headers compare SOURCE_ENGINE against SE_<NAME> constants, and
    # they reference engines other than the one being built (`#if SOURCE_ENGINE
    # == SE_TF2` and such). Upstream defines the entire table for every build;
    # without it those comparisons reference undefined symbols.
    se_defines = [
        "SE_{}={}".format(name, code)
        for name, code in sorted(_SOURCE_ENGINE_CODES.items())
    ]

    # The per-branch metadata is substituted into one shared overlay, so
    # adding an engine needs no new BUILD file.
    repository_ctx.template(
        "BUILD.bazel",
        repository_ctx.attr._build_file,
        substitutions = {
            "%{branch}": branch,
            "%{source_engine_code}": str(spec["code"]),
            "%{se_defines}": json.encode(se_defines),
            "%{include_paths}": json.encode(spec["include_paths"]),
            "%{defines}": json.encode(spec["defines"]),
            "%{posix_defines}": json.encode(spec.get("posix_defines", [])),
            # A branch with no 64-bit SDK has no lib_*_x86_64 entry; fall back
            # to the 32-bit directory since nothing ever selects the 64-bit
            # cc_import for it. See the comment on these fields above.
            "%{lib_linux_x86_32}": spec.get("lib_linux_x86_32", ""),
            "%{lib_linux_x86_64}": spec.get("lib_linux_x86_64", spec.get("lib_linux_x86_32", "")),
            "%{lib_windows_x86_32}": spec.get("lib_windows_x86_32", ""),
            "%{lib_windows_x86_64}": spec.get("lib_windows_x86_64", spec.get("lib_windows_x86_32", "")),
        },
        executable = False,
    )

hl2sdk_repository = repository_rule(
    implementation = _hl2sdk_impl,
    doc = "Fetches one engine branch of the HL2SDK.",
    attrs = {
        "branch": attr.string(
            doc = "Engine branch name, a key of HL2SDK_BRANCHES.",
            mandatory = True,
            values = HL2SDK_BRANCHES.keys(),
        ),
        "_build_file": attr.label(
            default = Label("//hl2sdk:hl2sdk.BUILD.bazel"),
            allow_single_file = True,
        ),
        "_ep1_movzx_patch": attr.label(
            default = Label("//patches:hl2sdk-ep1-movzx-operand-size.patch"),
            allow_single_file = True,
        ),
        "_ep1_memalloc_patch": attr.label(
            default = Label("//patches:hl2sdk-ep1-memalloc-include.patch"),
            allow_single_file = True,
        ),
        "_ep1_ssemath_patch": attr.label(
            default = Label("//patches:hl2sdk-ep1-ssemath-clang.patch"),
            allow_single_file = True,
        ),
        "_ep1_mathlib_base_patch": attr.label(
            default = Label("//patches:hl2sdk-ep1-mathlib-base-clang.patch"),
            allow_single_file = True,
        ),
    },
)

def _hl2sdk_extension_impl(module_ctx):
    wanted = {}
    for module in module_ctx.modules:
        for tag in module.tags.branch:
            wanted[tag.name] = True

    for branch in wanted:
        hl2sdk_repository(
            name = "hl2sdk_" + branch,
            branch = branch,
        )

    if wanted:
        metamod_repository(
            name = "metamod_source",
            branches = sorted(wanted),
        )

hl2sdk = module_extension(
    implementation = _hl2sdk_extension_impl,
    doc = """Fetches HL2SDK engine branches and Metamod:Source.

Each `branch` tag materializes one @hl2sdk_<name> repository. Metamod is fetched
once, shared by all of them, and builds one core per requested branch:

    hl2sdk = use_extension("@rules_sourcemod//hl2sdk:repositories.bzl", "hl2sdk")
    hl2sdk.branch(name = "css")
    use_repo(hl2sdk, "hl2sdk_css", "metamod_source")

Nothing is fetched unless a branch is requested, so the multi-hundred-megabyte
download only happens for builds that actually need an engine SDK.
""",
    tag_classes = {
        "branch": tag_class(attrs = {
            "name": attr.string(
                doc = "Engine branch, a key of HL2SDK_BRANCHES in this file.",
                mandatory = True,
            ),
        }),
    },
)

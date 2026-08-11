"""Repository rules that fetch the HL2SDK and Metamod:Source.

These replace the `git clone hl2sdk-manifests` + `configure.py --hl2sdk-root`
dance in upstream's build.sh. As with the SourceMod SDK, everything is pinned
and fetched through Bazel's downloader.

Unlike @sourcemod_sdk, the HL2SDK is *not* pure source: Valve ships tier0 and
vstdlib as prebuilt binaries only (the tree has a tier0_exclude.vpc and no
tier0 sources). Those binaries are consumed as-is; see hl2sdk.BUILD.bazel.
"""

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
    # which is checked eagerly at package load regardless of which cc_import
    # a build actually selects) -- it just doesn't contain files under the
    # names this overlay looks for, so building //hl2sdk:hl2sdk_ep1 (or
    # anything depending on it) for a linux_x86_* platform fails at the
    # missing-file stage today.
    #
    # Also untested against a real compiler on any platform: this entry adds
    # the manifest data only. Building it will very likely need source-level
    # patches (this SDK snapshot predates AMBuild and was only ever built
    # with a period MSVC) -- e.g. public/tier0/memalloc.h calls
    # IsPowerOfTwo() (tier0/commonmacros.h) without including that header,
    # which is a genuine missing #include rather than an MSVC-only
    # tolerance, and will fail on any compiler unless something else in the
    # translation unit happens to pull commonmacros.h in first.
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

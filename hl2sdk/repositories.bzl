"""Repository rules that fetch the HL2SDK and Metamod:Source.

These replace the `git clone hl2sdk-manifests` + `configure.py --hl2sdk-root`
dance in upstream's build.sh. As with the SourceMod SDK, everything is pinned
and fetched through Bazel's downloader.

Unlike @sourcemod_sdk, the HL2SDK is *not* pure source: Valve ships tier0 and
vstdlib as prebuilt binaries only (the tree has a tier0_exclude.vpc and no
tier0 sources). Those binaries are consumed as-is; see hl2sdk.BUILD.bazel.
"""

# alliedmodders/metamod-source. Supplies SourceHook and the ISmmAPI/ISmmPlugin
# headers; a Metamod extension cannot be compiled without it.
#
# Two release lines are pinned because they are not interchangeable in one
# direction: only the 2.0 line has a Source 2 provider, so a Source 2 engine
# branch (cs2) cannot be built from 1.12. The reverse is not a problem -- 2.0
# still carries the Source 1 provider and upstream's own 2.0 drops ship
# metamod.2.css.so -- so when a build asks for both kinds of branch at once,
# _metamod_line() resolves to 2.0 and both cores come out of the same tree.
#
# 1.12 stays the default so that a Source 1 build gets the line upstream calls
# stable rather than the development one.
#
# amtl is a git submodule of metamod-source at third_party/amtl. GitHub's
# archive tarballs never carry submodule contents -- the directory is present
# but empty -- so it is fetched separately and laid down at the path the sources
# expect. Metamod's core needs it (`#include <amtl/am-string.h>`), so without
# this the core does not compile.
#
# Each amtl_commit is Metamod's own pin, read from the gitlink at that line's
# commit (`git ls-tree <commit> third_party/amtl`). It is NOT the same commit
# SourceMod pins for its own copy of amtl; the two trees track it independently,
# so these must be re-read when bumping a commit rather than copied from
# //sourcemod:repositories.bzl.
_METAMOD_LINES = {
    # branch 1.12-dev
    "1.12": {
        "commit": "afc8233eedcd0c832b411c1da852328328db5c50",
        "amtl_commit": "285b4f853c0003023838140113e3ec066bd800c6",
    },
    # branch master, which is where product.version reads 2.0.0-dev
    "2.0": {
        "commit": "2667e8e5947237c4cb7ea45cec3913ad6a44757c",
        "amtl_commit": "285b4f853c0003023838140113e3ec066bd800c6",
    },
}

# Ordered weakest-first: when several branches disagree, the last one wins.
_METAMOD_LINE_ORDER = ["1.12", "2.0"]

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
#   source2: whether this is a Source 2 engine. The two generations share
#           almost nothing in the SDK's shape -- see hl2sdk_source2.BUILD.bazel
#           -- so this selects the build overlay as well as the Metamod
#           provider, and it is what forces the 2.0 Metamod line.
#   defines/include_paths: copied from the manifest for that branch.
#
# The metadata mirrors the corresponding manifests/*.json in
# alliedmodders/hl2sdk-manifests, which is what upstream AMBuild reads. Adding
# a branch is an entry here, not new code -- for a Source 1 branch. A Source 2
# branch additionally needs its prebuilt library set to match the ones named in
# hl2sdk_source2.BUILD.bazel, which today is cs2's.
HL2SDK_BRANCHES = {
    "css": {
        "commit": "d0ddd91faed91af581c06df28354156ae31b0bdb",
        "code": 6,
        "define": "CSS",
        "extension": "2.css",
        "source2": False,
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
    },
    # Counter-Strike 2. `_GLIBCXX_USE_CXX11_ABI=0` is not a style choice: the
    # manifest sets it because Valve's own libtier0.so exports the pre-C++11
    # std::string ABI, and a core built the other way links but then cannot
    # resolve those symbols at dlopen. The manifest's other half of that
    # decision, uses_system_cxxlib=false, is not reproduced -- see the linkopts
    # comment in hl2sdk_source2.BUILD.bazel for why, and what follows from it.
    "cs2": {
        "commit": "159cddd44cef4d9d607ef4ec4ac9f85cf056494c",
        "code": 25,
        "define": "CS2",
        "extension": "2.cs2",
        "source2": True,
        "defines": [],
        "posix_defines": ["_GLIBCXX_USE_CXX11_ABI=0"],
        # The protobuf drop vendored in the tree. Named separately because the
        # overlay globs it and passes it to protoc, and the version is in the
        # path, so it moves when Valve bumps protobuf.
        "protobuf_dir": "thirdparty/protobuf-3.21.8",
        "include_paths": [
            "thirdparty/protobuf-3.21.8/src",
            "public",
            "public/engine",
            "public/mathlib",
            "public/tier0",
            "public/tier1",
            "public/entity2",
            "public/game/server",
            "game/shared",
            "game/server",
            "common",
        ],
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

def _metamod_line(branches):
    """Returns the Metamod release line that can build all of `branches`."""
    line = _METAMOD_LINE_ORDER[0]
    for branch in branches:
        required = "2.0" if HL2SDK_BRANCHES[branch]["source2"] else "1.12"
        if _METAMOD_LINE_ORDER.index(required) > _METAMOD_LINE_ORDER.index(line):
            line = required
    return line

def _metamod_impl(repository_ctx):
    pins = _METAMOD_LINES[repository_ctx.attr.line]

    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/metamod-source/archive/{}.tar.gz".format(
            pins["commit"],
        ),
        stripPrefix = "metamod-source-" + pins["commit"],
    )

    # The amtl submodule, laid down where the sources `#include <amtl/...>`
    # from. See the comment on _METAMOD_LINES.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/amtl/archive/{}.tar.gz".format(
            pins["amtl_commit"],
        ),
        output = "third_party/amtl",
        stripPrefix = "amtl-" + pins["amtl_commit"],
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
            "source2": HL2SDK_BRANCHES[branch]["source2"],
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
        "line": attr.string(
            doc = "Release line to fetch, a key of _METAMOD_LINES.",
            mandatory = True,
        ),
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

    if spec["source2"]:
        # The vendored protobuf drop is itself a Bazel workspace, and its
        # BUILD.bazel would carve `thirdparty/<protobuf>` out into a package of
        # its own -- at which point the overlay's glob for the protobuf headers
        # matches nothing, because globs do not cross package boundaries. The
        # markers are removed so the drop stays part of this repository's root
        # package. Nothing here builds protobuf from source; only its headers
        # are read, and the runtime comes from the prebuilt archive.
        for marker in ["BUILD.bazel", "WORKSPACE"]:
            repository_ctx.delete("{}/{}".format(spec["protobuf_dir"], marker))

    # The SDK headers compare SOURCE_ENGINE against SE_<NAME> constants, and
    # they reference engines other than the one being built (`#if SOURCE_ENGINE
    # == SE_TF2` and such). Upstream defines the entire table for every build;
    # without it those comparisons reference undefined symbols.
    se_defines = [
        "SE_{}={}".format(name, code)
        for name, code in sorted(_SOURCE_ENGINE_CODES.items())
    ]

    # One overlay per engine generation; the per-branch metadata is substituted
    # in, so adding an engine needs no new BUILD file. The two generations get
    # different files because a Source 2 SDK shares neither the prebuilt library
    # set nor the from-source tier1/mathlib of a Source 1 one -- expressing that
    # as selects inside one overlay would be a file where every target is
    # conditional on something no single build uses both sides of.
    repository_ctx.template(
        "BUILD.bazel",
        repository_ctx.attr._source2_build_file if spec["source2"] else repository_ctx.attr._build_file,
        substitutions = {
            "%{branch}": branch,
            "%{source_engine_code}": str(spec["code"]),
            "%{se_defines}": json.encode(se_defines),
            "%{include_paths}": json.encode(spec["include_paths"]),
            "%{defines}": json.encode(spec["defines"]),
            "%{posix_defines}": json.encode(spec.get("posix_defines", [])),
            "%{protobuf_dir}": spec.get("protobuf_dir", ""),
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
        "_source2_build_file": attr.label(
            default = Label("//hl2sdk:hl2sdk_source2.BUILD.bazel"),
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
        branches = sorted(wanted)
        metamod_repository(
            name = "metamod_source",
            line = _metamod_line(branches),
            branches = branches,
        )

hl2sdk = module_extension(
    implementation = _hl2sdk_extension_impl,
    doc = """Fetches HL2SDK engine branches and Metamod:Source.

Each `branch` tag materializes one @hl2sdk_<name> repository. Metamod is fetched
once, shared by all of them, and builds one core per requested branch:

    hl2sdk = use_extension("@rules_sourcemod//hl2sdk:repositories.bzl", "hl2sdk")
    hl2sdk.branch(name = "css")
    use_repo(hl2sdk, "hl2sdk_css", "metamod_source")

The Metamod release line follows from the branches asked for: requesting a
Source 2 branch (cs2) selects the 2.0 line, which is the only one with a Source
2 provider. See _METAMOD_LINES.

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

"""Repository rules for HL2SDK engine branches and Metamod:Source."""

# alliedmodders/metamod-source (1.12-dev) and its third_party/amtl submodule
# (`git ls-tree <commit> third_party/amtl` -- tracked independently of SourceMod's amtl).
_METAMOD_COMMIT = "afc8233eedcd0c832b411c1da852328328db5c50"
_METAMOD_SHA256 = "9372148977224b4f769930e2c699c2147c9a4afade6de1b9df8c3126713be360"
_METAMOD_AMTL_COMMIT = "285b4f853c0003023838140113e3ec066bd800c6"
_METAMOD_AMTL_SHA256 = "5d5d70247ff2933d7495069f12e038736dcdd69fceff35aa6d7c5073c11f81a8"

_DEFAULT_INCLUDE_PATHS = [
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
]

_DEFAULT_POSIX_DEFINES = ["NO_HOOK_MALLOC", "NO_MALLOC_OVERRIDE"]

# Engine branches of alliedmodders/hl2sdk, mirroring alliedmodders/hl2sdk-manifests.
# Omitting `lib_*_x86_64` marks a branch 32-bit-only; omitting `lib_linux_x86_32`
# marks it Windows-only (see branch_target_compatible_with).
HL2SDK_BRANCHES = {
    "css": {
        "commit": "d0ddd91faed91af581c06df28354156ae31b0bdb",
        "sha256": "c575cd418c94d289f4f20563e7ad552496378588b148fc9c79452f3f0f61fa9b",
        "define": "CSS",
        "extension": "2.css",
        "defines": ["CSTRIKE_DLL"],
        "lib_linux_x86_32": "lib/public/linux",
        "lib_linux_x86_64": "lib/public/linux64",
        "lib_windows_x86_32": "lib/public/x86",
        "lib_windows_x86_64": "lib/public/x64",
    },
    "tf2": {
        "commit": "764e759c878c0f18e199f0048cbd3c025d73cf88",
        "sha256": "c01aba19d5a32903d91aabd8e5e7f6dfe9600792f727f27eea4729f2cf73f357",
        "define": "TF2",
        "extension": "2.tf2",
        "defines": ["TF_DLL"],
        "lib_linux_x86_32": "lib/public/linux",
        "lib_linux_x86_64": "lib/public/linux64",
        "lib_windows_x86_32": "lib/public/x86",
        "lib_windows_x86_64": "lib/public/x64",
    },
    "hl2dm": {
        "commit": "11dca0f12e53089b9dee6511f6b8ff4d02c9d51d",
        "sha256": "cb1193a2bcc0ce1f46e0a6892adf7f42216574e8927881fbe538b3a06636099b",
        "define": "HL2DM",
        "extension": "2.hl2dm",
        "defines": ["HL2_DLL", "HL2MP"],
        "lib_linux_x86_32": "lib/public/linux",
        "lib_linux_x86_64": "lib/public/linux64",
        "lib_windows_x86_32": "lib/public/x86",
        "lib_windows_x86_64": "lib/public/x64",
    },
    "dods": {
        "commit": "cbc97391097ed5c2790ab3fac6f9d05661d3a10f",
        "sha256": "6115b10b88fea904c99fb5e1a00c992c6afc887097114d927b312f33bba051df",
        "define": "DODS",
        "extension": "2.dods",
        "defines": ["DOD_DLL"],
        "lib_linux_x86_32": "lib/public/linux",
        "lib_linux_x86_64": "lib/public/linux64",
        "lib_windows_x86_32": "lib/public/x86",
        "lib_windows_x86_64": "lib/public/x64",
    },
    "l4d2": {
        "commit": "2a31cd007b2d7d2f964dc093eedcf7a812cf9dd6",
        "sha256": "53f158f4b29ab2908255a81d16a43d98d3b623b0e43bb0b18d4d42b421f51a9b",
        "define": "LEFT4DEAD2",
        "extension": "2.l4d2",
        "lib_linux_x86_32": "lib/linux",
        "lib_windows_x86_32": "lib/public",
    },
    "sdk2013": {
        "commit": "4c56ee5bc8bfe00793abb7d40eb3f6fb040f10d2",
        "sha256": "2a34f704e05e0143440cd3ba16d6ba5b0838d9e0a6b2d494e36009bce786f52a",
        "define": "SDK2013",
        "extension": "2.sdk2013",
        "lib_linux_x86_32": "lib/public/linux32",
        "lib_windows_x86_32": "lib/public",
    },
    # Pre-Orange Box Source engine (e.g. The Hidden: Source). Uses the older
    # `public/dlls` + `game_shared` layout; Linux libs (`linux_sdk/*_i486.so`)
    # are unwired since supported ep1 servers are Windows-only.
    "ep1": {
        "commit": "4b0cde271be6806b95842e78348009712a8b3fbe",
        "sha256": "d54d1f90110d18466406a0ef27c13f84c7453a23265e42b2eeeb79897549e72a",
        "define": "EPISODEONE",
        "extension": "2.ep1",
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
        "lib_windows_x86_32": "lib/public",
    },
}

# Full SE_* table defined on every build so `#if SOURCE_ENGINE == SE_<OTHER>` compiles.
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

def branch_target_compatible_with(spec):
    """Derives platform compatibility constraints from an HL2SDK_BRANCHES entry.

    Args:
      spec: Branch metadata dict from `HL2SDK_BRANCHES`.

    Returns:
      List of `@platforms` constraint labels required by the branch.
    """
    constraints = []
    if "lib_linux_x86_64" not in spec and "lib_windows_x86_64" not in spec:
        constraints.append("@platforms//cpu:x86_32")
    if "lib_linux_x86_32" not in spec:
        constraints.append("@platforms//os:windows")
    return constraints

def _metamod_impl(rctx):
    rctx.download_and_extract(
        url = "https://github.com/alliedmodders/metamod-source/archive/{}.tar.gz".format(rctx.attr.commit),
        sha256 = rctx.attr.sha256,
        stripPrefix = "metamod-source-" + rctx.attr.commit,
    )
    rctx.download_and_extract(
        url = "https://github.com/alliedmodders/amtl/archive/{}.tar.gz".format(rctx.attr.amtl_commit),
        sha256 = rctx.attr.amtl_sha256,
        output = "third_party/amtl",
        stripPrefix = "amtl-" + rctx.attr.amtl_commit,
    )

    for patch in rctx.attr._patches:
        rctx.patch(patch, strip = 1)

    rctx.file("BUILD.bazel", rctx.read(rctx.attr._build_file))

metamod_repository = repository_rule(
    implementation = _metamod_impl,
    doc = "Fetches Metamod:Source and its amtl submodule.",
    attrs = {
        "amtl_commit": attr.string(default = _METAMOD_AMTL_COMMIT),
        "amtl_sha256": attr.string(default = _METAMOD_AMTL_SHA256),
        "commit": attr.string(default = _METAMOD_COMMIT),
        "sha256": attr.string(default = _METAMOD_SHA256),
        "_build_file": attr.label(
            default = Label("//hl2sdk:metamod.BUILD.bazel"),
            allow_single_file = True,
        ),
        "_patches": attr.label_list(
            default = [
                Label("//patches:metamod-build-date-version.patch"),
                Label("//patches:metamod-build-date-header.patch"),
                Label("//patches:metamod-clang-thiscall-thunk.patch"),
            ],
            allow_files = True,
        ),
    },
)

def _hl2sdk_impl(rctx):
    branch = rctx.attr.branch
    spec = HL2SDK_BRANCHES[branch]
    commit = rctx.attr.commit or spec["commit"]
    sha256 = rctx.attr.sha256 or spec["sha256"]

    rctx.download_and_extract(
        url = "https://github.com/alliedmodders/hl2sdk/archive/{}.tar.gz".format(commit),
        sha256 = sha256,
        stripPrefix = "hl2sdk-" + commit,
    )

    if branch == "ep1":
        for patch in rctx.attr._ep1_patches:
            rctx.patch(patch, strip = 1)

    se_defines = [
        "SE_{}={}".format(name, code)
        for name, code in sorted(_SOURCE_ENGINE_CODES.items())
    ]
    lib_linux_32 = spec.get("lib_linux_x86_32", spec.get("lib_windows_x86_32", ""))
    lib_windows_32 = spec.get("lib_windows_x86_32", "")

    rctx.template(
        "BUILD.bazel",
        rctx.attr._build_file,
        substitutions = {
            "%{source_engine_code}": str(_SOURCE_ENGINE_CODES[spec["define"]]),
            "%{se_defines}": json.encode(se_defines),
            "%{include_paths}": json.encode(spec.get("include_paths", _DEFAULT_INCLUDE_PATHS)),
            "%{defines}": json.encode(spec.get("defines", [])),
            "%{posix_defines}": json.encode(spec.get("posix_defines", _DEFAULT_POSIX_DEFINES)),
            "%{target_compatible_with}": json.encode(branch_target_compatible_with(spec)),
            "%{lib_linux_x86_32}": lib_linux_32,
            "%{lib_linux_x86_64}": spec.get("lib_linux_x86_64", lib_linux_32),
            "%{lib_windows_x86_32}": lib_windows_32,
            "%{lib_windows_x86_64}": spec.get("lib_windows_x86_64", lib_windows_32),
        },
        executable = False,
    )

hl2sdk_repository = repository_rule(
    implementation = _hl2sdk_impl,
    doc = "Fetches one engine branch of the HL2SDK.",
    attrs = {
        "branch": attr.string(
            mandatory = True,
            values = HL2SDK_BRANCHES.keys(),
        ),
        "commit": attr.string(doc = "Optional commit SHA override for alliedmodders/hl2sdk."),
        "sha256": attr.string(doc = "Optional SHA256 override for the hl2sdk archive."),
        "_build_file": attr.label(
            default = Label("//hl2sdk:hl2sdk.BUILD.bazel"),
            allow_single_file = True,
        ),
        # Fixes pre-AMBuild EP1 inline asm, missing includes, and Clang-strict constructs.
        "_ep1_patches": attr.label_list(
            default = [
                Label("//patches:hl2sdk-ep1-movzx-operand-size.patch"),
                Label("//patches:hl2sdk-ep1-memalloc-include.patch"),
                Label("//patches:hl2sdk-ep1-ssemath-clang.patch"),
                Label("//patches:hl2sdk-ep1-mathlib-base-clang.patch"),
            ],
            allow_files = True,
        ),
    },
)

"""Repository rules that fetch the SourceMod SDK and the SourcePawn compiler.

These replace upstream's `tools/checkout-deps.sh`, which cloned SourceMod at
HEAD along with its submodules. Everything here is pinned by commit SHA and
fetched through Bazel's downloader, so builds are hermetic and cacheable --
nothing tracks a moving ref such as `master`. That is the fix for the
`TODO: Figure out how to pin this to a stable version` in the old build.sh,
which cloned SourceMod at HEAD and produced unreproducible builds.

See "Upgrading SourceMod" in README.md for the bump procedure.
"""

# SourceMod release tag `1.13.0.7461` in alliedmodders/sourcemod.
_SOURCEMOD_COMMIT = "809392d1dc0436b064f1d2d03cc498551f2a97b9"

# Submodule SHAs recorded by the SourceMod tree at _SOURCEMOD_COMMIT. These are
# read straight from the gitlink entries, so the header set matches exactly what
# upstream's own `checkout-deps.sh` would have produced.
_AMTL_COMMIT = "03506b678bc5838d958b8d51d2f9bee19b1edd6d"
_SOURCEPAWN_COMMIT = "672b2cda216d7543e12fe3ce03201cd537162a8f"

# mimalloc, a submodule of SourcePawn at third_party/mimalloc -- AlliedModders'
# own fork, not upstream microsoft/mimalloc, since the VM calls into fork-only
# entry points (mi_theap_*, src/theap.c). SourcePawn 2's heap
# (vm/heap.cpp, vm/objects.cpp, vm/virtmem-*.cpp) is built on it, so it is
# linked into everything that carries the VM: spcomp, oldspcomp, and
# sourcemod.logic.so. Read from the gitlink at _SOURCEPAWN_COMMIT
# (`git ls-tree <commit> third_party/mimalloc` in alliedmodders/sourcepawn).
#
# SourcePawn's other submodules are not fetched: third_party/amtl is the same
# amtl the SDK already lays down at public/amtl (SourceMod's build points the
# compiler at that copy too), third_party/capstone is only used by smxdump,
# and third_party/gtest only by the test suite, none of which are built here.
_MIMALLOC_COMMIT = "ada6b76fb1f56a55f6c065ece255f15e9abe6c97"

# safetyhook, a submodule at public/safetyhook. CDetour's detours.h includes
# <safetyhook.hpp>, so any extension using CDetour (sdktools, cstrike) needs it.
# Zydis, safetyhook's own disassembler dependency, is vendored into that tree
# pre-amalgamated as a single Zydis.c/Zydis.h pair, so this is the last fetch in
# the chain -- it pulls in nothing further.
_SAFETYHOOK_COMMIT = "8c6692c85a6c41f5d89f744da57b5ba43515b4ec"

# The SourcePawn compiler (spcomp) and the SourcePawn standard library are both
# built/taken from the sources pinned above, so there are no binary artifacts to
# pin here. Nothing in this build downloads a prebuilt executable.

def _sourcemod_sdk_impl(repository_ctx):
    # The SDK is three upstream repositories that upstream stitches together
    # with git submodules. Fetch each and lay it out in the relative position
    # the SDK headers expect.
    #
    # GitHub archives wrap their contents in `<name>-<commit>/`; stripping that
    # prefix is what keeps the include paths in the BUILD overlay stable.

    # SourceMod itself: public/ headers, smsdk_ext.cpp, plugins/include/.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/sourcemod/archive/{}.tar.gz".format(
            _SOURCEMOD_COMMIT,
        ),
        output = "",
        stripPrefix = "sourcemod-" + _SOURCEMOD_COMMIT,
    )

    # AMTL, a submodule at public/amtl.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/amtl/archive/{}.tar.gz".format(
            _AMTL_COMMIT,
        ),
        output = "public/amtl",
        stripPrefix = "amtl-" + _AMTL_COMMIT,
    )

    # SourcePawn, a submodule at sourcepawn. Carries both compilers (spcomp and
    # the legacy oldspcomp), the VM, and a vendored zlib.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/sourcepawn/archive/{}.tar.gz".format(
            _SOURCEPAWN_COMMIT,
        ),
        output = "sourcepawn",
        stripPrefix = "sourcepawn-" + _SOURCEPAWN_COMMIT,
    )

    # mimalloc, a submodule of SourcePawn at third_party/mimalloc. See
    # _MIMALLOC_COMMIT.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/mimalloc/archive/{}.tar.gz".format(
            _MIMALLOC_COMMIT,
        ),
        output = "sourcepawn/third_party/mimalloc",
        stripPrefix = "mimalloc-" + _MIMALLOC_COMMIT,
    )

    # safetyhook, a submodule at public/safetyhook. See _SAFETYHOOK_COMMIT.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/safetyhook/archive/{}.tar.gz".format(
            _SAFETYHOOK_COMMIT,
        ),
        output = "public/safetyhook",
        stripPrefix = "safetyhook-" + _SAFETYHOOK_COMMIT,
    )

    # Pins the build timestamp; see //sourcemod:build_date.bzl. Applied after
    # every extraction above, since the compiler patches land in the
    # sourcepawn/ tree. One patch per file: repository_ctx.patch carries the line offset
    # accumulated in an earlier file of the same patch into the next one, so a
    # multi-file patch fails on its second file as soon as a hunk changes the
    # line count. Bazel's patcher also drops CR on read, so these are stored
    # LF-only even though the sources they apply to are CRLF.
    for patch in repository_ctx.attr._patches:
        repository_ctx.patch(patch, strip = 1)

    # Read the product version out of the fetched tree rather than hardcoding
    # it, so it always matches the pinned SourcePawn sources.
    product_version = repository_ctx.read("sourcepawn/product.version").strip()

    repository_ctx.template(
        "BUILD.bazel",
        repository_ctx.attr._build_file,
        substitutions = {"%{product_version}": product_version},
        executable = False,
    )

sourcemod_sdk_repository = repository_rule(
    implementation = _sourcemod_sdk_impl,
    doc = "Fetches SourceMod SDK sources (sourcemod + amtl + sourcepawn).",
    attrs = {
        "_build_file": attr.label(
            default = Label("//sourcemod:sdk.BUILD.bazel"),
            allow_single_file = True,
        ),
        "_patches": attr.label_list(
            default = [
                Label("//sourcemod:patches/build_date_version_header.patch"),
                Label("//sourcemod:patches/build_date_sourcemm_api.patch"),
                Label("//sourcemod:patches/spcomp_source_date_epoch.patch"),
                Label("//sourcemod:patches/oldspcomp_source_date_epoch.patch"),
            ],
            allow_files = True,
        ),
    },
)

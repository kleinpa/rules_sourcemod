"""Repository rules that fetch the SourceMod SDK and the SourcePawn compiler.

These replace upstream's `tools/checkout-deps.sh`, which cloned SourceMod at
HEAD along with its submodules. Everything here is pinned by commit SHA and
fetched through Bazel's downloader, so builds are hermetic and cacheable --
nothing tracks a moving ref such as `master`. That is the fix for the
`TODO: Figure out how to pin this to a stable version` in the old build.sh,
which cloned SourceMod at HEAD and produced unreproducible builds.

See "Upgrading SourceMod" in README.md for the bump procedure.
"""

# SourceMod release tag `1.12.0.7246` in alliedmodders/sourcemod.
_SOURCEMOD_COMMIT = "f8490c8104a844fbf1826cd8b8f22900b86adf8a"

# Submodule SHAs recorded by the SourceMod tree at _SOURCEMOD_COMMIT. These are
# read straight from the gitlink entries, so the header set matches exactly what
# upstream's own `checkout-deps.sh` would have produced.
_AMTL_COMMIT = "2d3b1a3378a3728637f26660c9ffc2df3189cf62"
_SOURCEPAWN_COMMIT = "11b22edb634b9764d19fd28699e03289cfd18520"

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

    # SourcePawn, a submodule at sourcepawn. Carries the compiler, the VM, and a
    # vendored zlib.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/sourcepawn/archive/{}.tar.gz".format(
            _SOURCEPAWN_COMMIT,
        ),
        output = "sourcepawn",
        stripPrefix = "sourcepawn-" + _SOURCEPAWN_COMMIT,
    )

    # safetyhook, a submodule at public/safetyhook. See _SAFETYHOOK_COMMIT.
    repository_ctx.download_and_extract(
        url = "https://github.com/alliedmodders/safetyhook/archive/{}.tar.gz".format(
            _SAFETYHOOK_COMMIT,
        ),
        output = "public/safetyhook",
        stripPrefix = "safetyhook-" + _SAFETYHOOK_COMMIT,
    )

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
    },
)

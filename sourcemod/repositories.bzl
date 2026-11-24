"""Repository rule that fetches the pinned SourceMod SDK and SourcePawn sources."""

# SourceMod 1.12.0.7260 (`1.12-dev` stable branch) and the submodule SHAs
# recorded by its gitlinks (`git ls-tree <commit> public/amtl public/safetyhook sourcepawn`).
_SOURCEMOD_COMMIT = "3f7460671f7adc4a3c6791a47d21ba3e7b5fba91"
_SOURCEMOD_SHA256 = "18c47fd16d7e8b2b7094982556f40a9897c44cd2265f13b03f3244e13f745c77"

_AMTL_COMMIT = "2d3b1a3378a3728637f26660c9ffc2df3189cf62"
_AMTL_SHA256 = "c952f201a010eb285d3c5d4c195d24292f7e07ca6574c57ea30db01469a6b5dc"

_SOURCEPAWN_COMMIT = "11b22edb634b9764d19fd28699e03289cfd18520"
_SOURCEPAWN_SHA256 = "2c0fadfcf7ce36b4313357ca61cb065094cf1a250993e0333d7fca42098d7f93"

_SAFETYHOOK_COMMIT = "8c6692c85a6c41f5d89f744da57b5ba43515b4ec"
_SAFETYHOOK_SHA256 = "1762ff74780780e1c9c7ac981d61fe1346c2c726c33f307849c5d96350e946ae"

def _sourcemod_sdk_impl(rctx):
    rctx.download_and_extract(
        url = "https://github.com/alliedmodders/sourcemod/archive/{}.tar.gz".format(rctx.attr.sourcemod_commit),
        sha256 = rctx.attr.sourcemod_sha256,
        stripPrefix = "sourcemod-" + rctx.attr.sourcemod_commit,
    )
    rctx.download_and_extract(
        url = "https://github.com/alliedmodders/amtl/archive/{}.tar.gz".format(rctx.attr.amtl_commit),
        sha256 = rctx.attr.amtl_sha256,
        output = "public/amtl",
        stripPrefix = "amtl-" + rctx.attr.amtl_commit,
    )
    rctx.download_and_extract(
        url = "https://github.com/alliedmodders/sourcepawn/archive/{}.tar.gz".format(rctx.attr.sourcepawn_commit),
        sha256 = rctx.attr.sourcepawn_sha256,
        output = "sourcepawn",
        stripPrefix = "sourcepawn-" + rctx.attr.sourcepawn_commit,
    )
    rctx.download_and_extract(
        url = "https://github.com/alliedmodders/safetyhook/archive/{}.tar.gz".format(rctx.attr.safetyhook_commit),
        sha256 = rctx.attr.safetyhook_sha256,
        output = "public/safetyhook",
        stripPrefix = "safetyhook-" + rctx.attr.safetyhook_commit,
    )

    # One patch per file: repository_ctx.patch carries line-offset deltas across
    # files in a multi-file diff. Stored LF-only (see .gitattributes).
    for patch in rctx.attr._patches:
        rctx.patch(patch, strip = 1)

    # spcomp embeds this version; upstream generates it in AMBuild.
    version = rctx.read("sourcepawn/product.version").strip()
    parts = version.split(".")
    rctx.file("generated/sourcemod_version.h", "\n".join([
        "#define SM_VERSION_FILE " + ",".join(parts + ["0"] * (4 - len(parts))),
        "#define SM_VERSION_STRING \"{}\"".format(version),
        "",
    ]))
    rctx.file("BUILD.bazel", rctx.read(rctx.attr._build_file))

sourcemod_sdk_repository = repository_rule(
    implementation = _sourcemod_sdk_impl,
    doc = "Fetches SourceMod SDK sources (sourcemod, amtl, sourcepawn, safetyhook).",
    attrs = {
        "amtl_commit": attr.string(default = _AMTL_COMMIT),
        "amtl_sha256": attr.string(default = _AMTL_SHA256),
        "safetyhook_commit": attr.string(default = _SAFETYHOOK_COMMIT),
        "safetyhook_sha256": attr.string(default = _SAFETYHOOK_SHA256),
        "sourcemod_commit": attr.string(default = _SOURCEMOD_COMMIT),
        "sourcemod_sha256": attr.string(default = _SOURCEMOD_SHA256),
        "sourcepawn_commit": attr.string(default = _SOURCEPAWN_COMMIT),
        "sourcepawn_sha256": attr.string(default = _SOURCEPAWN_SHA256),
        "_build_file": attr.label(
            default = Label("//sourcemod:sdk.BUILD.bazel"),
            allow_single_file = True,
        ),
        "_patches": attr.label_list(
            default = [
                Label("//patches:sourcemod-build-date-version.patch"),
                Label("//patches:sourcemod-build-date-api.patch"),
                Label("//patches:spcomp-source-date-epoch.patch"),
            ],
            allow_files = True,
        ),
    },
)

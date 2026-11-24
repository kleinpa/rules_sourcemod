"""`SourcePawnInfo` provider and `sourcemod_library` rule."""

load("@bazel_skylib//lib:paths.bzl", "paths")

SourcePawnInfo = provider(
    doc = "Transitive SourcePawn headers, sources, and `-i` include search roots.",
    fields = {
        "include_dirs": "depset[str]: `-i` search roots in topological preorder.",
        "transitive_hdrs": "depset[File]: `.inc` files required at compile time.",
        "transitive_srcs": "depset[File]: additional `.sp`/`.inc` files included by relative path.",
    },
)

def _include_root_for_file(ctx, hdr, strip_include_prefix):
    if strip_include_prefix.startswith("/"):
        rel = strip_include_prefix.lstrip("/")
        root = paths.normalize(paths.join(hdr.root.path, ctx.label.workspace_root, rel))
    else:
        root = paths.normalize(paths.join(
            hdr.root.path,
            ctx.label.workspace_root,
            ctx.label.package,
            strip_include_prefix,
        ))

    if root == ".":
        return "."

    prefix = root + "/"
    if not hdr.path.startswith(prefix):
        fail("header '{}' is not under strip_include_prefix '{}' (expected prefix '{}')".format(
            hdr.short_path,
            strip_include_prefix,
            prefix,
        ))
    return root

def source_pawn_info_from_hdrs(ctx, hdrs, strip_include_prefix = "", srcs = [], deps = []):
    """Builds a `SourcePawnInfo` from direct headers/sources and transitive deps."""
    direct_dirs = []
    for hdr in hdrs:
        inc_dir = _include_root_for_file(ctx, hdr, strip_include_prefix)
        if inc_dir not in direct_dirs:
            direct_dirs.append(inc_dir)

    return SourcePawnInfo(
        include_dirs = depset(
            direct = direct_dirs,
            transitive = [dep[SourcePawnInfo].include_dirs for dep in deps],
            order = "preorder",
        ),
        transitive_hdrs = depset(
            direct = hdrs,
            transitive = [dep[SourcePawnInfo].transitive_hdrs for dep in deps],
        ),
        transitive_srcs = depset(
            direct = srcs,
            transitive = [dep[SourcePawnInfo].transitive_srcs for dep in deps],
        ),
    )

def _sourcemod_library_impl(ctx):
    sp_info = source_pawn_info_from_hdrs(
        ctx = ctx,
        hdrs = ctx.files.hdrs,
        strip_include_prefix = ctx.attr.strip_include_prefix,
        srcs = ctx.files.srcs,
        deps = ctx.attr.deps,
    )
    return [
        DefaultInfo(
            files = depset(
                direct = ctx.files.hdrs + ctx.files.srcs,
                transitive = [sp_info.transitive_hdrs, sp_info.transitive_srcs],
            ),
        ),
        sp_info,
    ]

sourcemod_library = rule(
    implementation = _sourcemod_library_impl,
    doc = "Groups SourcePawn `.inc` headers and `.sp` sources with transitive include paths.",
    attrs = {
        "deps": attr.label_list(
            doc = "Transitive SourcePawn library or extension dependencies (`SourcePawnInfo`).",
            providers = [SourcePawnInfo],
        ),
        "hdrs": attr.label_list(
            doc = "Public `.inc` headers exposed on `-i` to dependents.",
            allow_files = [".inc"],
        ),
        "srcs": attr.label_list(
            doc = "Additional `.sp`/`.inc` files propagated for relative `#include`.",
            allow_files = [".sp", ".inc"],
        ),
        "strip_include_prefix": attr.string(
            default = "",
            doc = "Directory prefix to strip from `hdrs` when computing `-i` search paths (package-relative, or repo-relative if leading `/`).",
        ),
    },
    provides = [SourcePawnInfo],
)

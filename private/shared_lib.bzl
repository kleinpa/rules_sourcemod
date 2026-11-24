"""Shared helpers for picking loadable modules (.so / .dll) and rules_pkg metadata."""

load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")

def package_files_info(dest, files, mode = "0755"):
    """Builds a rules_pkg PackageFilesInfo placing `files` under `dest`."""
    return PackageFilesInfo(
        dest_src_map = {
            "{}/{}".format(dest, f.basename): f
            for f in files
        },
        attributes = {"mode": mode},
    )

def select_shared_lib(ctx):
    """Picks the `.dll` or `.so` loadable module from `ctx.files.binary`.

    Args:
      ctx: Rule context carrying `SHARED_LIB_ATTRS`.

    Returns:
      The loadable `.dll` or `.so` `File`.
    """
    is_windows = ctx.target_platform_has_constraint(
        ctx.attr._windows_constraint[platform_common.ConstraintValueInfo],
    )
    wanted = "dll" if is_windows else "so"
    for f in ctx.files.binary:
        if f.extension == wanted:
            return f
    fail("no '.{}' output found among: {}".format(
        wanted,
        [f.short_path for f in ctx.files.binary],
    ))

SHARED_LIB_ATTRS = {
    "binary": attr.label(
        allow_files = True,
        mandatory = True,
        doc = "A linkshared cc_binary target.",
    ),
    "_windows_constraint": attr.label(
        default = Label("@platforms//os:windows"),
    ),
}

def _shared_lib_output_impl(ctx):
    return [DefaultInfo(files = depset([select_shared_lib(ctx)]))]

shared_lib_output = rule(
    implementation = _shared_lib_output_impl,
    doc = "Narrows a linkshared cc_binary's outputs to its .so/.dll (dropping Windows' import .lib).",
    attrs = SHARED_LIB_ATTRS,
)

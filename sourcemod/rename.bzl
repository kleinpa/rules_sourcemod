"""rename_shared_lib / shared_lib_output — pick the loadable module out of a
linkshared cc_binary's outputs ('.so' on POSIX, '.dll' on Windows), dropping
the Windows-only import .lib built alongside it. The target configuration
needed to tell the two apart is only known at analysis time, so neither a
genrule (whose `outs` must be static) nor a plain pkg_files `renames` (which
has no way to filter a label's files, only rename them) can do this alone.

Two variants, for two different shapes of caller:

  rename_shared_lib gives the picked file a fixed name (declare_file +
  symlink). Safe for a target instantiated once per repo, or whose name
  already varies per caller (Metamod's per-branch core is named after the
  branch's `extension`, e.g. "metamod.2.css") -- declare_file's output path
  is the *package's*, not the target's, so two callers in the same package
  wanting the same fixed name (e.g. SourceMod's own "sourcemod.logic",
  built once per game-server preset, all four presets living in
  //sourcemod) would collide. See extension/defs.bzl's _rename_extension for
  the sibling version of this used by sourcemod_extension, which also picks
  an install directory since an extension always has exactly one -- this
  version doesn't: Metamod's loader/core are placed at different, arch/OS-
  varying paths by their own callers.

  shared_lib_output does not rename at all -- it keeps the binary's own
  (target-unique, since it's derived from the label) filename and only
  narrows DefaultInfo down to the one wanted file. That's what server.bzl's
  _shared_lib uses: with four-plus presets sharing one package, only a
  filter (not a new fixed-name output) is collision-safe, so the actual
  rename to e.g. "sourcemod.logic.so" happens where it always did, in the
  caller's own pkg_files `renames` (now select()ed on OS as well as arch).
"""

def _wanted_output(ctx):
    """Returns (is_windows, the '.so'/'.dll' File among ctx.files.binary)."""
    is_windows = ctx.target_platform_has_constraint(
        ctx.attr._windows_constraint[platform_common.ConstraintValueInfo],
    )
    wanted = "dll" if is_windows else "so"
    candidates = [f for f in ctx.files.binary if f.extension == wanted]
    if not candidates:
        fail("no '.{}' output found among: {}".format(
            wanted,
            [f.short_path for f in ctx.files.binary],
        ))
    return is_windows, candidates[0]

_BINARY_ATTR = {
    "binary": attr.label(
        allow_files = True,
        mandatory = True,
        doc = "A linkshared cc_binary target.",
    ),
    "_windows_constraint": attr.label(
        default = Label("@platforms//os:windows"),
    ),
}

def _rename_shared_lib_impl(ctx):
    _, src = _wanted_output(ctx)
    renamed = ctx.actions.declare_file("{}.{}".format(ctx.attr.filename, src.extension))
    ctx.actions.symlink(output = renamed, target_file = src)
    return [DefaultInfo(files = depset([renamed]))]

rename_shared_lib = rule(
    implementation = _rename_shared_lib_impl,
    doc = ("Renames a linkshared cc_binary's output to '<filename>.so' " +
           "(POSIX) or '<filename>.dll' (Windows). Only safe for a target " +
           "instantiated once per repo, or already named uniquely per " +
           "caller -- see the module docstring."),
    attrs = dict(_BINARY_ATTR, filename = attr.string(
        mandatory = True,
        doc = "Output basename, without extension.",
    )),
)

def _shared_lib_output_impl(ctx):
    _, src = _wanted_output(ctx)
    return [DefaultInfo(files = depset([src]))]

shared_lib_output = rule(
    implementation = _shared_lib_output_impl,
    doc = ("Narrows a linkshared cc_binary's outputs down to the '.so' " +
           "(POSIX) or '.dll' (Windows) one, keeping its original " +
           "(target-unique) filename -- safe to call from the same " +
           "package any number of times, unlike rename_shared_lib."),
    attrs = _BINARY_ATTR,
)

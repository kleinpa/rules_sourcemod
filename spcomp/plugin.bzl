"""`sourcemod_plugin` — compiles a SourcePawn source file into a .smx plugin."""

load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")
load("//sourcemod:providers.bzl", "SourceModPackageInfo", "package_providers")

def _sourcemod_plugin_impl(ctx):
    toolchain = ctx.toolchains["//spcomp:toolchain_type"].spcomp

    plugin_name = ctx.attr.plugin_name or ctx.label.name
    smx = ctx.actions.declare_file(plugin_name + ".smx")
    dest_dir = ctx.attr.dest_dir or "addons/sourcemod/plugins"

    args = ctx.actions.args()

    # spcomp resolves includes relative to its own location unless told
    # otherwise, which breaks under Bazel's sandbox. Derive the stdlib include
    # directory from the actual bundled files rather than from the compiler
    # path, so it stays correct regardless of how the toolchain is laid out.
    include_dirs = []
    stdlib_files = toolchain.stdlib_includes.to_list()
    if stdlib_files:
        include_dirs.append(stdlib_files[0].dirname)

    for dep in ctx.attr.includes:
        for inc in dep.files.to_list():
            if inc.dirname not in include_dirs:
                include_dirs.append(inc.dirname)
    args.add_all(include_dirs, format_each = "-i%s")

    # Treat warnings as errors: a plugin that compiles with warnings is almost
    # always a latent runtime bug, and the old build silently ignored them.
    if ctx.attr.werror:
        args.add("-E")

    for define in ctx.attr.defines:
        args.add(define)

    args.add("-o", smx)
    args.add(ctx.file.src)

    # extra_srcs are made available to the sandbox but never named on the
    # command line: a plugin split across several files pulls them in with
    # `#include "subdir/part.sp"`, which spcomp resolves relative to the
    # including file. They only have to exist at the right relative path.
    inputs = depset(
        direct = [ctx.file.src],
        transitive = [
            toolchain.stdlib_includes,
            depset([f for dep in ctx.attr.includes for f in dep.files.to_list()]),
            depset(ctx.files.extra_srcs),
        ],
    )

    ctx.actions.run(
        executable = toolchain.compiler,
        arguments = [args],
        inputs = inputs,
        outputs = [smx],
        mnemonic = "SpcompCompile",
        progress_message = "Compiling SourcePawn plugin %{label}",
        # spcomp writes intermediates next to its inputs and reads no ambient
        # state; caching is safe.
        execution_requirements = {"supports-workers": "0"},
    )

    return [
        DefaultInfo(files = depset([smx])),
    ] + package_providers(dest_dir, [smx])

sourcemod_plugin = rule(
    implementation = _sourcemod_plugin_impl,
    doc = """Compiles a SourcePawn (.sp) source file into a .smx plugin.

Example:

    sourcemod_plugin(
        name = "my_plugin",
        src = "my_plugin.sp",
        includes = [":my_natives_inc"],
    )
""",
    attrs = {
        "src": attr.label(
            doc = "The .sp source file to compile.",
            allow_single_file = [".sp"],
            mandatory = True,
        ),
        "includes": attr.label_list(
            doc = "Targets providing additional .inc files on the include path.",
            allow_files = [".inc"],
        ),
        "extra_srcs": attr.label_list(
            doc = """Additional source files the plugin `#include`s by relative
path, e.g. the `subdir/part.sp` files a multi-file plugin is split across.
These are placed in the sandbox but not passed to spcomp directly.""",
            allow_files = [".sp", ".inc"],
        ),
        "defines": attr.string_list(
            doc = "Extra flags passed verbatim to spcomp (e.g. 'SOME_MACRO=1').",
        ),
        "plugin_name": attr.string(
            doc = "Basename of the generated .smx. Defaults to the target name.",
        ),
        "werror": attr.bool(
            doc = "Treat SourcePawn warnings as errors.",
            default = True,
        ),
        "dest_dir": attr.string(
            doc = "Destination directory within the package (default: addons/sourcemod/plugins).",
        ),
    },
    toolchains = ["//spcomp:toolchain_type"],
    provides = [PackageFilesInfo, SourceModPackageInfo],
)

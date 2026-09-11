"""SourcePawn compiler toolchain.

Modelled as a real Bazel toolchain rather than a hardcoded binary path so that
consumers can register their own spcomp (a different SourceMod branch, or one
built from source) without forking these rules.
"""

SpcompInfo = provider(
    doc = "Information about a SourcePawn compiler installation.",
    fields = {
        "compiler": "File: the spcomp executable, which emits SourcePawn 2 bytecode.",
        "legacy_compiler": """File or None: the pre-2.0 compiler (oldspcomp), which
emits SourcePawn 1 bytecode. None if this toolchain has no such compiler, in
which case a plugin asking for `sourcepawn_version = "1"` fails to build.""",
        "stdlib_includes": "depset[File]: bundled .inc standard library files.",
    },
)

def _spcomp_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            spcomp = SpcompInfo(
                compiler = ctx.executable.compiler,
                legacy_compiler = ctx.executable.legacy_compiler,
                stdlib_includes = depset(ctx.files.stdlib_includes),
            ),
        ),
    ]

spcomp_toolchain = rule(
    implementation = _spcomp_toolchain_impl,
    doc = "Declares a SourcePawn compiler implementation.",
    attrs = {
        "compiler": attr.label(
            doc = "The spcomp executable (SourcePawn 2).",
            allow_files = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "legacy_compiler": attr.label(
            doc = """The pre-2.0 compiler (oldspcomp), for plugins built with
`sourcepawn_version = "1"`. Optional: a toolchain without one simply cannot
build those. Both compilers share `stdlib_includes` -- SourceMod's
plugins/include is written to compile under either.""",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        "stdlib_includes": attr.label(
            doc = "The SourcePawn standard library .inc files.",
            allow_files = True,
        ),
    },
)

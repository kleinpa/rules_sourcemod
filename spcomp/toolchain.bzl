"""SourcePawn compiler toolchain.

Modelled as a real Bazel toolchain rather than a hardcoded binary path so that
consumers can register their own spcomp (a different SourceMod branch, or one
built from source) without forking these rules.
"""

SpcompInfo = provider(
    doc = "Information about a SourcePawn compiler.",
    fields = {
        "compiler": "File: the spcomp executable.",
        "stdlib_includes": "depset[File]: bundled .inc standard library files.",
    },
)

def _spcomp_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            spcomp = SpcompInfo(
                compiler = ctx.executable.compiler,
                stdlib_includes = depset(ctx.files.stdlib_includes),
            ),
        ),
    ]

spcomp_toolchain = rule(
    implementation = _spcomp_toolchain_impl,
    doc = "Declares a SourcePawn compiler implementation.",
    attrs = {
        "compiler": attr.label(
            doc = "The spcomp executable.",
            allow_files = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "stdlib_includes": attr.label(
            doc = "The SourcePawn standard library .inc files.",
            allow_files = True,
        ),
    },
)

"""Generates SourcePawn's `sourcemod_version.h`.

Upstream produces this with a Python script (`tools/generate_version_header.py`)
driven by AMBuild. Reimplemented as a Starlark rule that writes the file
directly: `ctx.actions.write` needs no shell and no interpreter, so it behaves
identically on Linux, macOS, and Windows.

An earlier attempt used a genrule with an inline shell script. It hung on
Windows -- Bazel has to route `cmd` through a POSIX shell there, and the loop
that padded the version components did not terminate reliably. Emitting the file
from Starlark removes the shell from the picture entirely.
"""

def _sourcemod_version_header_impl(ctx):
    version = ctx.attr.version.strip()

    # The .rc file format wants four comma-separated components (1.12 -> 1,12,0,0).
    parts = version.split(".")
    if len(parts) > 4:
        fail("version '{}' has more than four components".format(version))
    padded = parts + ["0"] * (4 - len(parts))

    for part in padded:
        if not part.isdigit():
            fail("version '{}' has a non-numeric component '{}'".format(version, part))

    header = ctx.actions.declare_file(ctx.attr.header_name)
    ctx.actions.write(
        output = header,
        content = "\n".join([
            "#define SM_VERSION_FILE {}".format(",".join(padded)),
            "#define SM_VERSION_STRING \"{}\"".format(version),
            "",
        ]),
    )

    return [DefaultInfo(files = depset([header]))]

sourcemod_version_header = rule(
    implementation = _sourcemod_version_header_impl,
    doc = "Writes sourcemod_version.h for the SourcePawn compiler.",
    attrs = {
        "version": attr.string(
            doc = "Product version, e.g. '1.12'.",
            mandatory = True,
        ),
        "header_name": attr.string(
            doc = "Output path for the generated header.",
            default = "generated/sourcemod_version.h",
        ),
    },
)

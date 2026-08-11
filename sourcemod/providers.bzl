"""Providers shared between the extension, plugin, and packaging rules.

Artifacts declare where they install in a SourceMod server layout by returning
rules_pkg's `PackageFilesInfo`. That lets a consumer hand targets straight to
rules_pkg's `pkg_tar`/`pkg_zip` without knowing what kind of artifact each one
is, and it means the install layout is described once, by the rule that produces
the file.

`SourceModPackageInfo` is kept alongside it as a stable, rules_pkg-independent
view of the same information for consumers that want to introspect a package.
"""

load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")

SourceModPackageInfo = provider(
    doc = "Files a target contributes to a SourceMod server directory layout.",
    fields = {
        "files": """depset[(string, File)]: (destination directory, file) pairs,
            where the destination is relative to the server root, e.g.
            'addons/sourcemod/extensions'.""",
    },
)

def package_providers(dest, files):
    """Builds the providers describing where `files` install.

    Args:
      dest: destination directory relative to the server root, e.g.
        'addons/sourcemod/extensions'.
      files: list of File to install into `dest`.

    Returns:
      A list of providers: PackageFilesInfo (for rules_pkg) and
      SourceModPackageInfo (for introspection).
    """
    return [
        PackageFilesInfo(
            dest_src_map = {
                "{}/{}".format(dest, f.basename): f
                for f in files
            },
            attributes = {"mode": "0755"},
        ),
        SourceModPackageInfo(
            files = depset(direct = [(dest, f) for f in files]),
        ),
    ]

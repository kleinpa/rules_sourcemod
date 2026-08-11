"""Analysis tests for the install layout declared by extensions and plugins.

These assert the contract consumers rely on to assemble their own archives:
every artifact rule reports, at analysis time, exactly where its output
installs in a SourceMod server directory. Getting this wrong produces an
archive that extracts to the wrong place -- a failure that is invisible
until someone deploys it, which is precisely why it is worth a test.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")
load("//sourcemod:providers.bzl", "SourceModPackageInfo")

def _install_paths(env):
    """Returns the archive-relative destinations of the target under test."""
    target = analysistest.target_under_test(env)
    return sorted(target[PackageFilesInfo].dest_src_map.keys())

# ---------------------------------------------------------------------------
# Extensions install into addons/sourcemod/extensions with an OS-correct suffix.
# ---------------------------------------------------------------------------

def _extension_layout_test_impl(ctx):
    env = analysistest.begin(ctx)
    paths = _install_paths(env)

    asserts.equals(env, 1, len(paths))

    # Both the OS suffix and the x64 subdirectory are chosen from the target
    # platform, which varies with the host running these tests, so assert the
    # part of the contract that is invariant: the install directory (with or
    # without the x64 subdirectory), the base name, and a loadable-module
    # suffix. `extension_suffix_test` below pins the platform-specific half.
    path = paths[0]
    asserts.true(
        env,
        path.startswith("addons/sourcemod/extensions/"),
        "unexpected install path: {}".format(path),
    )
    asserts.true(
        env,
        path.endswith("/test_ext.ext.so") or path.endswith("/test_ext.ext.dll"),
        "unexpected install path: {}".format(path),
    )
    return analysistest.end(env)

extension_layout_test = analysistest.make(_extension_layout_test_impl)

def _extension_suffix_test_impl(ctx):
    env = analysistest.begin(ctx)
    paths = _install_paths(env)

    # SourceMod loads `.dll` on Windows and `.so` elsewhere; shipping the wrong
    # one silently fails to load at runtime.
    asserts.equals(env, [ctx.attr.expected_path], paths)
    return analysistest.end(env)

def _make_suffix_test(platform):
    return analysistest.make(
        _extension_suffix_test_impl,
        attrs = {"expected_path": attr.string(mandatory = True)},
        config_settings = {
            "//command_line_option:platforms": str(Label(platform)),
        },
    )

extension_linux_suffix_test = _make_suffix_test("//platforms:linux_x86_32")
extension_windows_suffix_test = _make_suffix_test("//platforms:windows_x86_32")

# ---------------------------------------------------------------------------
# Plugins install into addons/sourcemod/plugins.
# ---------------------------------------------------------------------------

def _plugin_layout_test_impl(ctx):
    env = analysistest.begin(ctx)
    paths = _install_paths(env)

    asserts.equals(
        env,
        ["addons/sourcemod/plugins/test_plugin.smx"],
        paths,
    )
    return analysistest.end(env)

plugin_layout_test = analysistest.make(_plugin_layout_test_impl)

# ---------------------------------------------------------------------------
# Both rule types also expose the rules_pkg-independent view of the same data.
# ---------------------------------------------------------------------------

def _package_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    entries = target[SourceModPackageInfo].files.to_list()
    asserts.equals(env, 1, len(entries))

    dest, _file = entries[0]
    asserts.true(
        env,
        dest in ctx.attr.expected_dests,
        "unexpected package dest: {} (wanted one of {})".format(dest, ctx.attr.expected_dests),
    )
    return analysistest.end(env)

package_info_test = analysistest.make(
    _package_info_test_impl,
    attrs = {"expected_dests": attr.string_list(mandatory = True)},
)

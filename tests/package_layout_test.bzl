"""Analysis tests for the rules_pkg install paths declared by extensions and plugins."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_pkg//pkg:providers.bzl", "PackageFilesInfo")

def _install_paths(env):
    target = analysistest.target_under_test(env)
    return sorted(target[PackageFilesInfo].dest_src_map.keys())

def _extension_layout_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, sorted(ctx.attr.expected_paths), _install_paths(env))
    return analysistest.end(env)

def _make_extension_layout_test(platform):
    return analysistest.make(
        _extension_layout_test_impl,
        attrs = {"expected_paths": attr.string_list(mandatory = True)},
        config_settings = {
            "//command_line_option:platforms": str(Label(platform)),
        },
    )

extension_linux_suffix_test = _make_extension_layout_test("//platforms:linux_x86_64")
extension_windows_suffix_test = _make_extension_layout_test("//platforms:windows_x86_32")

def _plugin_layout_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(
        env,
        ["addons/sourcemod/plugins/test_plugin.smx"],
        _install_paths(env),
    )
    return analysistest.end(env)

plugin_layout_test = analysistest.make(_plugin_layout_test_impl)

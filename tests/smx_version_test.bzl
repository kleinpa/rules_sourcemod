"""Asserts that `sourcemod_plugin` emits SourcePawn 1 bytecode (major version 0x01 at offset 5)."""

load("@rules_cc//cc:defs.bzl", "cc_test")

def smx_version_test(name, plugin):
    cc_test(
        name = name,
        size = "small",
        srcs = ["smx_version_test.cc"],
        args = ["$(rlocationpath {})".format(plugin)],
        data = [plugin],
        deps = ["@rules_cc//cc/runfiles"],
    )

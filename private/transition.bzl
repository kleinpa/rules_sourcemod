"""Platform transition rule that preserves rules_pkg install-path providers."""

load("@rules_pkg//pkg:providers.bzl", "PackageFilegroupInfo", "PackageFilesInfo")

def _transition_platform_impl(_, attr):
    return {"//command_line_option:platforms": str(attr.target_platform)}

_transition_platform = transition(
    implementation = _transition_platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _platform_transition_pkg_impl(ctx):
    src = ctx.attr.src[0]
    providers = [src[DefaultInfo]]
    if PackageFilesInfo in src:
        providers.append(src[PackageFilesInfo])
    if PackageFilegroupInfo in src:
        providers.append(src[PackageFilegroupInfo])
    return providers

platform_transition_pkg = rule(
    implementation = _platform_transition_pkg_impl,
    doc = "Transitions a rules_pkg source (preset, extension, or plugin) to target_platform while forwarding PackageFilesInfo/PackageFilegroupInfo.",
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "src": attr.label(
            cfg = _transition_platform,
            mandatory = True,
            doc = "Target to transition.",
        ),
        "target_platform": attr.label(
            mandatory = True,
            doc = "Destination platform label.",
        ),
    },
)

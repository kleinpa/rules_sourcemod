"""`sourcemod_test` — compiles a SourcePawn (.sp) test and runs it in `spshell`."""

load("@bazel_skylib//rules:native_binary.bzl", "native_test")
load("//spcomp:plugin.bzl", "sourcemod_plugin")

_COMMON_ATTR_NAMES = (
    "compatible_with",
    "exec_compatible_with",
    "tags",
    "target_compatible_with",
)

def sourcemod_test(
        name,
        src,
        deps = [],
        includes = [],
        extra_srcs = [],
        copts = [],
        defines = [],
        werror = True,
        shell = Label("@sourcemod_sdk//:spshell"),
        size = "small",
        visibility = None,
        **kwargs):
    """Compiles a `.sp` file and executes its `public main()` entry point in `spshell`.

    Tests run headlessly in the standalone SourcePawn VM (no `srcds` or SourceMod
    engine natives) with `<spshell>` on the include path (`assert_eq`, `assert_true`,
    `assert_false`, `assert_streq`, `print`, `printf`).

    Args:
      name: Test target name.
      src: `.sp` test source file defining `public int main()` or `public void main()`.
      deps: `sourcemod_library` or `sourcemod_extension` targets providing `SourcePawnInfo`.
      includes: Additional `.inc` targets to add to the include path.
      extra_srcs: Additional `.sp`/`.inc` files included by relative path.
      copts: Extra flags passed to `spcomp`.
      defines: Preprocessor defines passed to `spcomp`.
      werror: Whether to treat `spcomp` warnings as errors (defaults to `True`).
      shell: Standalone SourcePawn shell binary (defaults to `@sourcemod_sdk//:spshell`).
      size: Bazel test size (defaults to `"small"`).
      visibility: Target visibility.
      **kwargs: Additional test attributes (`timeout`, `flaky`, `tags`, etc.) forwarded
        to the underlying test rule.
    """
    common_attrs = {
        k: kwargs.pop(k)
        for k in _COMMON_ATTR_NAMES
        if k in kwargs
    }

    smx_name = name + "_smx"
    sourcemod_plugin(
        name = smx_name,
        src = src,
        deps = deps,
        includes = [Label("//spcomp:spshell_includes")] + includes,
        extra_srcs = extra_srcs,
        copts = copts,
        defines = defines,
        werror = werror,
        testonly = True,
        visibility = ["//visibility:private"],
        **common_attrs
    )

    native_test(
        name = name,
        src = Label("//spcomp:spshell_runner"),
        args = [
            "$(rlocationpath {})".format(shell),
            "$(rlocationpath :{})".format(smx_name),
        ],
        data = [
            shell,
            ":" + smx_name,
        ],
        size = size,
        visibility = visibility,
        **(dict(common_attrs, **kwargs))
    )

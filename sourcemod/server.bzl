"""sourcemod_game_server — compiles SourceMod + Metamod for a game server image.

Private to //sourcemod; depend on the ready-made presets in //sourcemod:BUILD.bazel
(`sourcemod_cstrike`, `sourcemod_tf2`, `sourcemod_l4d2`, `sourcemod_sdk2013`, `sourcemod_ep1`).
Bundled SourcePawn plugins are intentionally omitted so deployments pick only
what they want via `//sourcemod:plugin_<name>`.
"""

load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_filegroup", "pkg_files", "strip_prefix")
load("//hl2sdk:repositories.bzl", "HL2SDK_BRANCHES", "branch_target_compatible_with")
load("//private:flags.bzl", "SERVER_COPTS", "SERVER_LINKOPTS", "WINDOWS_CRT_FEATURES")
load("//private:shared_lib.bzl", "shared_lib_output")

visibility("private")

_SM = "@sourcemod_sdk"
_X86_64 = "@platforms//cpu:x86_64"
_WINDOWS = "@platforms//os:windows"
_WINDOWS_X86_64 = "@rules_sourcemod//platforms:is_windows_x86_64"
_PRIVATE = ["//visibility:private"]

# Branches for which upstream ships a dedicated `extensions/<game>` binary.
_GAME_EXTENSIONS = {
    "css": "cstrike",
    "tf2": "tf2",
}

def _with_ext(stem_map, suffix):
    return {target: "{}.{}".format(stem, suffix) for target, stem in stem_map.items()}

def _shared_lib(name, srcs, deps, target_compatible_with, defines = []):
    """Compiles per-engine `srcs` into a `linkshared` `cc_binary` and narrows output to `.so`/`.dll`."""
    cc_binary(
        name = name + "_bin",
        srcs = srcs,
        copts = SERVER_COPTS,
        defines = defines,
        features = WINDOWS_CRT_FEATURES,
        linkopts = SERVER_LINKOPTS,
        linkshared = True,
        deps = deps,
        target_compatible_with = target_compatible_with,
        visibility = _PRIVATE,
    )
    shared_lib_output(
        name = name,
        binary = ":" + name + "_bin",
        target_compatible_with = target_compatible_with,
        visibility = _PRIVATE,
    )

def sourcemod_game_server(name, branch, visibility = None):
    """Compiles SourceMod + Metamod for `branch` into a `pkg_filegroup`.

    Engine-independent binaries (`loader`, `logic`, `sourcepawn_vm_shared`,
    `topmenus`, `bintools`, `clientprefs`, `sqlite`, `geoip`, `regex`,
    `metamod_loader`) are shared across branches from `@sourcemod_sdk` and
    `@metamod_source`; only HL2SDK-coupled binaries are compiled per branch.
    Every target here carries
    the branch's `target_compatible_with`, so `bazel build //...` skips (and
    never fetches) branches the target platform cannot run.

    Args:
      name: Target name of the resulting `pkg_filegroup`.
      branch: Engine branch key in `HL2SDK_BRANCHES`.
      visibility: Visibility of the `pkg_filegroup`.
    """
    spec = HL2SDK_BRANCHES[branch]
    ext = spec["extension"]
    game = _GAME_EXTENSIONS.get(branch)
    compat = branch_target_compatible_with(spec)
    hl2sdk = "@hl2sdk_{}//:hl2sdk".format(branch)
    p = name + "_"

    # Per-engine SourceMod core and HL2SDK-linked extensions.
    _shared_lib(
        name = p + "core",
        srcs = [_SM + "//:core_srcs"],
        defines = select({
            "@rules_cc//cc/compiler:msvc-cl": ["_ALLOW_KEYWORD_MACROS"],
            "//conditions:default": [],
        }),
        deps = [_SM + "//:sm_root_hdrs", hl2sdk],
        target_compatible_with = compat,
    )
    _shared_lib(
        name = p + "sdktools",
        srcs = [_SM + "//:sdktools_srcs"],
        defines = ["HAVE_STRING_H", "HOOKING_ENABLED"],
        deps = [_SM + "//:sdktools_hdrs", hl2sdk, "@hl2sdk_{}//:hl2sdk_game_server".format(branch)],
        target_compatible_with = compat,
    )
    _shared_lib(
        name = p + "sdkhooks",
        srcs = [_SM + "//:sdkhooks_srcs"],
        deps = [_SM + "//:sdkhooks_hdrs", hl2sdk],
        target_compatible_with = compat,
    )
    if game:
        _shared_lib(
            name = p + "game",
            srcs = [_SM + "//:{}_srcs".format(game)],
            defines = ["HAVE_STRING_H"],
            deps = [_SM + "//:{}_hdrs".format(game), hl2sdk],
            target_compatible_with = compat,
        )

    # Loader always installs in bin/ (never bin/x64/), taking an .x64 stem on 64-bit.
    loader = _SM + "//:loader"
    pkg_files(
        name = p + "bin_loader_files",
        attributes = pkg_attributes(mode = "0755"),
        srcs = [loader],
        prefix = "addons/sourcemod/bin",
        renames = select({
            _WINDOWS_X86_64: {loader: "sourcemod_mm.x64.dll"},
            _X86_64: {loader: "sourcemod_mm.x64.so"},
            _WINDOWS: {loader: "sourcemod_mm.dll"},
            "//conditions:default": {loader: "sourcemod_mm.so"},
        }),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    # Core, logic, and the SourcePawn runtime (`sourcepawn.vm` on x64, `sourcepawn.jit.x86` on x86).
    bin_stems_x64 = {
        ":" + p + "core": "sourcemod." + ext,
        _SM + "//:logic": "sourcemod.logic",
        _SM + "//:sourcepawn_vm_shared": "sourcepawn.vm",
    }
    bin_stems_x86 = dict(bin_stems_x64, **{_SM + "//:sourcepawn_vm_shared": "sourcepawn.jit.x86"})
    pkg_files(
        name = p + "bin_runtime_files",
        attributes = pkg_attributes(mode = "0755"),
        srcs = bin_stems_x64.keys(),
        prefix = select({
            _X86_64: "addons/sourcemod/bin/x64",
            "//conditions:default": "addons/sourcemod/bin",
        }),
        renames = select({
            _WINDOWS_X86_64: _with_ext(bin_stems_x64, "dll"),
            _X86_64: _with_ext(bin_stems_x64, "so"),
            _WINDOWS: _with_ext(bin_stems_x86, "dll"),
            "//conditions:default": _with_ext(bin_stems_x86, "so"),
        }),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    ext_stems = {
        ":" + p + "sdktools": "sdktools.ext." + ext,
        ":" + p + "sdkhooks": "sdkhooks.ext." + ext,
        _SM + "//:topmenus": "topmenus.ext",
        _SM + "//:bintools": "bintools.ext",
        _SM + "//:clientprefs": "clientprefs.ext",
        _SM + "//:sqlite": "dbi.sqlite.ext",
        _SM + "//:geoip": "geoip.ext",
        _SM + "//:regex": "regex.ext",
    }
    autoload_srcs = [
        _SM + "//:sdktools.autoload",
        _SM + "//:sdkhooks.autoload",
        _SM + "//:topmenus.autoload",
        _SM + "//:bintools.autoload",
    ]
    if game:
        ext_stems[":" + p + "game"] = "game.{}.ext.{}".format(game, ext)
        autoload_srcs.append(_SM + "//:game.{}.autoload".format(game))

    pkg_files(
        name = p + "ext_files",
        attributes = pkg_attributes(mode = "0755"),
        srcs = ext_stems.keys(),
        prefix = select({
            _X86_64: "addons/sourcemod/extensions/x64",
            "//conditions:default": "addons/sourcemod/extensions",
        }),
        renames = select({
            _WINDOWS: _with_ext(ext_stems, "dll"),
            "//conditions:default": _with_ext(ext_stems, "so"),
        }),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    pkg_files(
        name = p + "autoload_files",
        srcs = autoload_srcs,
        prefix = "addons/sourcemod/extensions",
        strip_prefix = strip_prefix.from_pkg(),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    pkg_files(
        name = p + "data_files",
        srcs = [
            _SM + "//:configs",
            _SM + "//:gamedata",
            _SM + "//:translations",
        ],
        prefix = "addons/sourcemod",
        strip_prefix = strip_prefix.from_pkg(),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    pkg_files(
        name = p + "cfg_files",
        srcs = [_SM + "//:configs_cfg"],
        prefix = "cfg/sourcemod",
        strip_prefix = strip_prefix.from_pkg("configs/cfg"),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    pkg_files(
        name = p + "vdf_files",
        srcs = [_SM + "//:sourcemod_vdf"],
        prefix = "addons/metamod",
        strip_prefix = strip_prefix.from_pkg("configs/metamod"),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    # Metamod loader + per-branch core + engine VDF.
    metamod_stems = {
        "@metamod_source//:metamod_core_" + branch: "metamod." + ext,
        "@metamod_source//:metamod_loader": "server",
    }
    pkg_files(
        name = p + "metamod_bin_files",
        attributes = pkg_attributes(mode = "0755"),
        srcs = metamod_stems.keys(),
        prefix = select({
            _WINDOWS_X86_64: "addons/metamod/bin/win64",
            _X86_64: "addons/metamod/bin/linux64",
            "//conditions:default": "addons/metamod/bin",
        }),
        renames = select({
            _WINDOWS: _with_ext(metamod_stems, "dll"),
            "//conditions:default": _with_ext(metamod_stems, "so"),
        }),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    pkg_files(
        name = p + "metamod_vdf_files",
        srcs = select({
            _WINDOWS_X86_64: ["@metamod_source//:support/metamod_win64.vdf"],
            _X86_64: ["@metamod_source//:support/metamod_linux64.vdf"],
            "//conditions:default": ["@metamod_source//:support/metamod.vdf"],
        }),
        prefix = "addons",
        renames = select({
            _WINDOWS_X86_64: {"@metamod_source//:support/metamod_win64.vdf": "metamod_win64.vdf"},
            _X86_64: {"@metamod_source//:support/metamod_linux64.vdf": "metamod_x64.vdf"},
            "//conditions:default": {"@metamod_source//:support/metamod.vdf": "metamod.vdf"},
        }),
        target_compatible_with = compat,
        visibility = _PRIVATE,
    )

    pkg_filegroup(
        name = name,
        srcs = [
            ":" + p + "bin_loader_files",
            ":" + p + "bin_runtime_files",
            ":" + p + "ext_files",
            ":" + p + "autoload_files",
            ":" + p + "data_files",
            ":" + p + "cfg_files",
            ":" + p + "vdf_files",
            ":" + p + "metamod_bin_files",
            ":" + p + "metamod_vdf_files",
        ],
        target_compatible_with = compat,
        visibility = visibility,
    )

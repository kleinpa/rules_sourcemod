"""sourcemod_game_server — compiles SourceMod + Metamod for a game server image.

This macro is designed to be called from a game-server BUILD file (e.g. the
counterstrikesource-server repository) where the `hl2sdk` module extension has
been used to request `branch` (which makes both @hl2sdk_<branch> and
@metamod_source visible). It cannot live in sdk.BUILD.bazel because the
@sourcemod_sdk repo is created by the `sourcemod` extension independently of
the `hl2sdk` extension, so @hl2sdk_* labels are not in its repo mapping.

SourceMod cannot run without Metamod -- sourcemod_mm.so is loaded *by*
Metamod, not by the engine directly -- so the two are assembled together into
one target rather than left for the caller to combine.

The macro compiles every SourceMod deliverable from source:
  - sourcemod_mm(.64).so         MetaMod plugin loader
  - sourcemod.logic.so           logic subsystem (no HL2SDK dep)
  - sourcemod.<ext>.so           core, e.g. sourcemod.2.css.so
  - sdktools.ext.<ext>.so        SDK tools extension
  - sdkhooks.ext.<ext>.so        SDK hooks extension
  - <game>.ext.<ext>.so          per-game extension, e.g. game.cstrike.ext.2.css.so
  - topmenus.ext.so              top menus extension
  - bintools.ext.so              binary tools extension

plus Metamod's own loader and per-branch core (from @metamod_source, fetched
by the `hl2sdk` extension alongside the engine branch). It then assembles
those outputs together with @sourcemod_sdk's sourcepawn.vm.so and static data
files into a single pkg_filegroup -- a PackageFilegroupInfo-bearing target,
like sourcemod_extension/sourcemod_plugin carry PackageFilesInfo, with no
archive format or install prefix baked in. The caller feeds it to their own
pkg_tar/pkg_zip alongside anything else going into the same image layer.

Bundled SourcePawn plugins are deliberately NOT included: which of
SourceMod's ~24 stock plugins (basecommands, nextmap, mapchooser, ...) a
server actually wants is a per-deployment choice, not something this macro
should decide. Pull in whichever ones are wanted from @sourcemod_sdk
directly, e.g. `@sourcemod_sdk//:plugin_basecommands` -- see
//sourcemod:plugins.bzl for the full ACTIVE_PLUGINS/DISABLED_PLUGINS lists.

`<ext>` is the branch's manifest `extension` field from HL2SDK_BRANCHES (e.g.
"2.css") -- the same suffix Metamod uses for its own per-branch core
(metamod.<ext>.so) -- since it names which engine/game the binary was built
against, not the source that produced it.

Usage (in a game-server BUILD.bazel):

    load("@rules_sourcemod//sourcemod:server.bzl", "sourcemod_game_server")
    load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

    sourcemod_game_server(
        name = "sourcemod",
        branch = "css",
    )

    pkg_tar(
        name = "sourcemod_layer",
        srcs = [
            ":sourcemod",
            "@sourcemod_sdk//:plugin_basecommands",
            "@sourcemod_sdk//:plugin_nextmap",
        ],
        package_dir = "/opt/game/cstrike",
    )
"""

load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_filegroup", "pkg_files", "strip_prefix")
load("//hl2sdk:repositories.bzl", "HL2SDK_BRANCHES")
load("//sourcemod:warnings.bzl", "UPSTREAM_WARNING_COPTS")

_SM = "@sourcemod_sdk"

# SourceMod's own directory layout puts 64-bit binaries in a bin/x64 and
# extensions/x64 subdirectory alongside the 32-bit originals, rather than
# replacing them -- there is no equivalent "32-bit subdirectory" to select
# instead. See platforms/BUILD.bazel for where this config_setting comes from.
_X86_64 = "@rules_sourcemod//platforms:x86_64"

# Compiler flags that mirror SM's own AMBuilder configuration for server
# components (MMS.Library / SM.Library / SM.HL2Library / SM.HL2ExtConfig).
_COPTS_COMMON = select({
    "@rules_cc//cc/compiler:msvc-cl": ["/W3", "/EHsc", "/GR-"],
    "//conditions:default": [
        "-std=c++17",
        "-fPIC",
        "-fno-strict-aliasing",
        "-fno-rtti",
    ],
}) + UPSTREAM_WARNING_COPTS

_LINKOPTS_POSIX = select({
    "@platforms//os:linux": ["-lpthread", "-lrt", "-ldl"],
    "//conditions:default": [],
})

# Per-game "game extension" (SM.HL2ExtConfig with a Game_Extension section):
# implements the natives specific to one game, e.g. extensions/cstrike for
# Counter-Strike: Source. Unlike sdktools/sdkhooks/topmenus/bintools, this
# source differs per game, not just per engine build -- so it is the one part
# of the macro that genuinely needs a per-branch table rather than a suffix
# derived from HL2SDK_BRANCHES.
#
# Adding a game here also needs a `<name>_srcs` / `<name>_hdrs` filegroup in
# sdk.BUILD.bazel (see cstrike_srcs/cstrike_hdrs for the pattern) and an entry
# in HL2SDK_BRANCHES (//hl2sdk:repositories.bzl) for the engine it targets.
_GAME_EXTENSIONS = {
    "css": {
        "game": "cstrike",
        "srcs": _SM + "//:cstrike_srcs",
        "hdrs": _SM + "//:cstrike_hdrs",
    },
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _shared_lib(name, lib_name, deps, linkopts = [], visibility = ["//visibility:private"], tags = []):
    """cc_binary with linkshared + genrule that renames lib<name>.so → lib_name."""
    cc_binary(
        name = name + "_raw",
        linkshared = True,
        deps = deps,
        linkopts = linkopts,
        visibility = visibility,
        tags = tags,
    )
    native.genrule(
        name = name,
        srcs = [":" + name + "_raw"],
        outs = [lib_name],
        cmd = "cp $(SRCS) $@",
        visibility = visibility,
        tags = tags,
    )

# ---------------------------------------------------------------------------
# Public macro
# ---------------------------------------------------------------------------

def sourcemod_game_server(
        name,
        branch,
        visibility = None,
        tags = []):
    """Compiles SourceMod + Metamod into a single packaging target.

    Args:
        name: Target name. The final pkg_filegroup is accessible as `:{name}`
            and can be passed directly as a `pkg_tar`/`pkg_zip` src.
        branch: Engine branch to build for, a key of both HL2SDK_BRANCHES
            (//hl2sdk:repositories.bzl) and _GAME_EXTENSIONS above. The
            caller's MODULE.bazel must have requested it via
            `hl2sdk.branch(name = branch)` and `use_repo`d the resulting
            `@hl2sdk_<branch>` and `@metamod_source` repos.
        visibility: Passed to the final pkg_filegroup.
        tags: Applied to every target the macro creates (the final
            pkg_filegroup and all its private intermediates), e.g.
            `["manual"]` to keep a build that needs a fetched engine SDK out
            of `bazel build //...`.
    """
    if branch not in _GAME_EXTENSIONS:
        fail((
            "sourcemod_game_server: no game extension registered for " +
            "branch {!r} in _GAME_EXTENSIONS (sourcemod/server.bzl). " +
            "Known branches: {}"
        ).format(branch, sorted(_GAME_EXTENSIONS.keys())))

    game = _GAME_EXTENSIONS[branch]
    ext = HL2SDK_BRANCHES[branch]["extension"]  # e.g. "2.css"

    hl2sdk = "@hl2sdk_{}//:hl2sdk".format(branch)
    hl2sdk_game_server = "@hl2sdk_{}//:hl2sdk_game_server".format(branch)
    metamod_headers = "@metamod_source//:metamod_headers"

    p = name + "_"  # private target prefix

    # -----------------------------------------------------------------------
    # Loader — sourcemod_mm.so/sourcemod_mm.x64.so
    # MetaMod plugin shim; only needs MetaMod headers, no HL2SDK.
    # -----------------------------------------------------------------------
    cc_library(
        name = p + "loader_lib",
        srcs = [_SM + "//:loader_srcs"],
        copts = _COPTS_COMMON,
        defines = ["META_NO_HL2SDK"],
        deps = [
            _SM + "//:sourcemod_headers",
            metamod_headers,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # x64 suffix is applied afterward as a pkg_files rename below.
    _shared_lib(
        name = p + "loader",
        lib_name = "sourcemod_mm.so",
        deps = [p + "loader_lib"],
        linkopts = select({
            "@platforms//os:linux": ["-ldl"],
            "//conditions:default": [],
        }),
        tags = tags,
    )

    # -----------------------------------------------------------------------
    # Logic — sourcemod.logic.so
    # Pure C++; depends on SourceHook (from MetaMod headers) but no HL2SDK.
    # -----------------------------------------------------------------------
    cc_library(
        name = p + "logic_lib",
        srcs = [_SM + "//:logic_srcs"],
        copts = _COPTS_COMMON,
        defines = ["SM_DEFAULT_THREADER", "SM_LOGIC"],
        deps = [
            _SM + "//:sm_root_hdrs",
            metamod_headers,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )
    _shared_lib(
        name = p + "logic",
        lib_name = "sourcemod.logic.so",
        deps = [p + "logic_lib"],
        linkopts = _LINKOPTS_POSIX,
        tags = tags,
    )

    # -----------------------------------------------------------------------
    # Core — sourcemod.<ext>.so
    # MetaMod plugin proper; needs the full HL2SDK to call game APIs.
    # -----------------------------------------------------------------------
    cc_library(
        name = p + "core_lib",
        srcs = [_SM + "//:core_srcs"],
        copts = _COPTS_COMMON,
        defines = select({
            "@rules_cc//cc/compiler:msvc-cl": ["_ALLOW_KEYWORD_MACROS"],
            "//conditions:default": [],
        }),
        deps = [
            _SM + "//:sm_root_hdrs",
            metamod_headers,
            hl2sdk,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )
    _shared_lib(
        name = p + "core",
        lib_name = "sourcemod.{}.so".format(ext),
        deps = [p + "core_lib"],
        linkopts = _LINKOPTS_POSIX,
        tags = tags,
    )

    # -----------------------------------------------------------------------
    # Extensions — each produces <name>.ext[.<ext>].so
    # -----------------------------------------------------------------------

    # sdktools — needs CDetour, the JIT headers, and the SDK's server-side
    # game headers (variant_t.h and friends).
    cc_library(
        name = p + "sdktools_lib",
        srcs = [_SM + "//:sdktools_srcs"],
        copts = _COPTS_COMMON,
        defines = ["HAVE_STRING_H", "HOOKING_ENABLED"],
        deps = [
            _SM + "//:sdktools_hdrs",
            hl2sdk,
            hl2sdk_game_server,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )
    _shared_lib(
        name = p + "sdktools",
        lib_name = "sdktools.ext.{}.so".format(ext),
        deps = [p + "sdktools_lib"],
        linkopts = _LINKOPTS_POSIX,
        tags = tags,
    )

    # sdkhooks
    cc_library(
        name = p + "sdkhooks_lib",
        srcs = [_SM + "//:sdkhooks_srcs"],
        copts = _COPTS_COMMON,
        deps = [
            _SM + "//:sdkhooks_hdrs",
            hl2sdk,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )
    _shared_lib(
        name = p + "sdkhooks",
        lib_name = "sdkhooks.ext.{}.so".format(ext),
        deps = [p + "sdkhooks_lib"],
        linkopts = _LINKOPTS_POSIX,
        tags = tags,
    )

    # Per-game extension, e.g. cstrike — game-specific, no rulesfix.cpp
    cc_library(
        name = p + "game_lib",
        srcs = [game["srcs"]],
        copts = _COPTS_COMMON,
        defines = ["HAVE_STRING_H"],
        deps = [
            game["hdrs"],
            hl2sdk,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )
    _shared_lib(
        name = p + "game",
        lib_name = "game.{}.ext.{}.so".format(game["game"], ext),
        deps = [p + "game_lib"],
        linkopts = _LINKOPTS_POSIX,
        tags = tags,
    )

    # topmenus — SM.ExtLibrary: no HL2SDK dep; needs SourceHook from MetaMod
    cc_library(
        name = p + "topmenus_lib",
        srcs = [_SM + "//:topmenus_srcs"],
        copts = _COPTS_COMMON,
        deps = [
            _SM + "//:topmenus_hdrs",
            metamod_headers,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )
    _shared_lib(
        name = p + "topmenus",
        lib_name = "topmenus.ext.so",
        deps = [p + "topmenus_lib"],
        linkopts = _LINKOPTS_POSIX,
        tags = tags,
    )

    # bintools — SM.ExtLibrary: needs SourceHook + JIT headers; no HL2SDK
    cc_library(
        name = p + "bintools_lib",
        srcs = [_SM + "//:bintools_srcs"],
        copts = _COPTS_COMMON,
        defines = ["HOOKING_ENABLED"],
        deps = [
            _SM + "//:bintools_hdrs",
            metamod_headers,
        ],
        alwayslink = True,
        visibility = ["//visibility:private"],
        tags = tags,
    )
    _shared_lib(
        name = p + "bintools",
        lib_name = "bintools.ext.so",
        deps = [p + "bintools_lib"],
        linkopts = _LINKOPTS_POSIX,
        tags = tags,
    )

    # -----------------------------------------------------------------------
    # Assembly — pkg_files per destination directory, then one pkg_tar
    # -----------------------------------------------------------------------

    # Loader lives in bin/ (not bin/x64/) on every arch: MetaMod expects it
    # there. Its filename does still take the x64 suffix on a 64-bit target,
    # applied here since the genrule producing it can't be select()'d (see
    # the loader's own comment above).
    pkg_files(
        name = p + "bin_loader_files",
        attributes = pkg_attributes(mode = "0755"),
        srcs = [":" + p + "loader"],
        prefix = "addons/sourcemod/bin",
        renames = select({
            _X86_64: {":" + p + "loader": "sourcemod_mm.x64.so"},
            "//conditions:default": {},
        }),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # Core, logic and the SourcePawn runtime live in bin/x64/ on a 64-bit
    # target, bin/ directly on a 32-bit one. The runtime is built in
    # @sourcemod_sdk rather than here because, unlike everything else the
    # macro assembles, it depends on neither the HL2SDK nor MetaMod.
    pkg_files(
        name = p + "bin_x64_files",
        attributes = pkg_attributes(mode = "0755"),
        srcs = [
            ":" + p + "core",
            ":" + p + "logic",
            _SM + "//:sourcepawn_vm_so",
        ],
        prefix = select({
            _X86_64: "addons/sourcemod/bin/x64",
            "//conditions:default": "addons/sourcemod/bin",
        }),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # Extensions in extensions/x64/ on a 64-bit target, extensions/ directly
    # on a 32-bit one.
    pkg_files(
        name = p + "ext_files",
        attributes = pkg_attributes(mode = "0755"),
        srcs = [
            ":" + p + "sdktools",
            ":" + p + "sdkhooks",
            ":" + p + "game",
            ":" + p + "topmenus",
            ":" + p + "bintools",
        ],
        prefix = select({
            _X86_64: "addons/sourcemod/extensions/x64",
            "//conditions:default": "addons/sourcemod/extensions",
        }),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # Autoload sentinels in extensions/ (not extensions/x64/).
    pkg_files(
        name = p + "autoload_files",
        srcs = [_SM + "//:autoload_files"],
        prefix = "addons/sourcemod/extensions",
        strip_prefix = strip_prefix.from_pkg(),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # Static data: configs, gamedata, translations.
    #
    # strip_prefix.from_pkg() with no argument strips only the package path,
    # which is empty at an external repo root -- so the leading `configs/`,
    # `gamedata/` and `translations/` component survives and lands under the
    # prefix, matching CopyFiles('gamedata', 'addons/sourcemod/gamedata') in
    # upstream's PackageScript. Passing the directory name here instead would
    # strip that component and flatten everything into addons/sourcemod/.
    pkg_files(
        name = p + "configs_files",
        srcs = [_SM + "//:configs"],
        prefix = "addons/sourcemod",
        strip_prefix = strip_prefix.from_pkg(),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    pkg_files(
        name = p + "gamedata_files",
        srcs = [_SM + "//:gamedata"],
        prefix = "addons/sourcemod",
        strip_prefix = strip_prefix.from_pkg(),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    pkg_files(
        name = p + "translations_files",
        srcs = [_SM + "//:translations"],
        prefix = "addons/sourcemod",
        strip_prefix = strip_prefix.from_pkg(),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # Server console configs: configs/cfg/* -> cfg/sourcemod/*.
    pkg_files(
        name = p + "cfg_files",
        srcs = [_SM + "//:configs_cfg"],
        prefix = "cfg/sourcemod",
        strip_prefix = strip_prefix.from_pkg("configs/cfg"),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # SourceMod's MetaMod VDF. Placed at addons/metamod/ so MetaMod sees it.
    pkg_files(
        name = p + "vdf_files",
        srcs = [_SM + "//:sourcemod_vdf"],
        prefix = "addons/metamod",
        strip_prefix = strip_prefix.from_pkg("configs/metamod"),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # -----------------------------------------------------------------------
    # Metamod itself — the loader SourceMod's own binaries above are loaded
    # by, plus the per-branch core it dlopens by SOURCE_ENGINE at runtime.
    # SourceMod cannot run without this, so it ships in the same layer rather
    # than left for the caller to assemble separately.
    # -----------------------------------------------------------------------
    pkg_files(
        name = p + "metamod_bin_files",
        srcs = [
            "@metamod_source//:metamod_core_{}".format(branch),
            "@metamod_source//:metamod_loader",
        ],
        attributes = pkg_attributes(mode = "0755"),
        prefix = "addons/metamod/bin/linux64",
        strip_prefix = strip_prefix.from_pkg(),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    pkg_files(
        name = p + "metamod_vdf_files",
        srcs = ["@metamod_source//:metamod_x64_vdf"],
        prefix = "addons",
        strip_prefix = strip_prefix.from_pkg(),
        visibility = ["//visibility:private"],
        tags = tags,
    )

    # Final merged group -- a PackageFilegroupInfo-bearing target, not an
    # archive. The caller decides the format (pkg_tar/pkg_zip), the install
    # prefix (package_dir), and which bundled plugins (if any) to add
    # alongside this from @sourcemod_sdk//:plugin_<name>; this macro only
    # says where the engine/Metamod-dependent pieces go relative to a server
    # root.
    pkg_filegroup(
        name = name,
        srcs = [
            ":" + p + "bin_loader_files",
            ":" + p + "bin_x64_files",
            ":" + p + "ext_files",
            ":" + p + "autoload_files",
            ":" + p + "configs_files",
            ":" + p + "gamedata_files",
            ":" + p + "translations_files",
            ":" + p + "cfg_files",
            ":" + p + "vdf_files",
            ":" + p + "metamod_bin_files",
            ":" + p + "metamod_vdf_files",
        ],
        visibility = visibility,
        tags = tags,
    )

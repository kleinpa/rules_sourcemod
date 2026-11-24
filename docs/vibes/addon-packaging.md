# Addon Packaging

## Goal

One label per addon should carry everything the addon installs, with paths
relative to the game-mod root (such as `cstrike/`). The same label should work
in both places addons are consumed:

- **Release archives**: a `pkg_tar` / `pkg_zip` unpacked over a game directory.
- **Server image layers**: a `pkg_tar` combining many addons, as in
  [counterstrikesource-server](https://github.com/kleinpa/counterstrikesource-server/blob/main/BUILD.bazel).
  The server repo should not need to know which extra files a plugin uses.

## Companion files

`sourcemod_plugin` and `sourcemod_extension` package only compiled output (plus
`.autoload`). Any other file needs hand-written `pkg_files` and `pkg_filegroup`.
Proposed attributes:

| Attribute      | Installs to                                                        |
| -------------- | ------------------------------------------------------------------ |
| `gamedata`     | `addons/sourcemod/gamedata/`                                       |
| `translations` | `addons/sourcemod/translations/`, keeping `<lang>/` subdirectories |
| `configs`      | `addons/sourcemod/configs/`                                        |
| `cfgs`         | `cfg/sourcemod/`                                                   |
| `game_files`   | Mod root: `materials/`, `models/`, `sound/`, `scripts/`, `cfg/`    |

`PackageFilesInfo` holds a single file mode for all its files. That decides where
the attributes can live:

- **`sourcemod_plugin`** installs as `0644`, so data files can join its existing
  `PackageFilesInfo`.
- **`sourcemod_extension`** installs as `0755`, so adding `0644` data files means
  returning `PackageFilegroupInfo` instead, or using the wrapper below.
  (`.autoload` files are already installed as `0755` for this reason.)

## Multi-part addons

Addons with several parts (extension + plugin, or plugin + assets) should expose
a root `pkg_filegroup`, with the release archive as a separate target:

```starlark
pkg_filegroup(
    name = "my_addon",
    srcs = ["//extension:my_addon", "//plugin:my_addon"],
    visibility = ["//visibility:public"],
)

pkg_tar(
    name = "my_addon_tar",
    srcs = [":my_addon"],
    extension = "tar.gz",
)
```

A root `pkg_filegroup` preserves each part's file mode and works with both
`pkg_tar(package_dir = ...)` and `platform_transition_pkg`. Making the root a
`pkg_tar` would not: consumers would end up nesting one tar inside another.
[auth-by-steam-group](https://github.com/lanofdoom/auth-by-steam-group) already
uses this layout.

Document this pattern in `README.md`. If it stays repetitive, add a
`sourcemod_addon` macro that wraps `pkg_filegroup` and takes the attributes above.

## `AutoExecConfig` stubs

When a plugin calls `AutoExecConfig(true, ...)` and its `cfg/sourcemod/<name>.cfg`
is missing, SourceMod writes one containing the convar defaults and executes it,
overriding values set in `server.cfg`. Shipping an empty file prevents this.

`counterstrikesource-server` does so with `write_file` + `pkg_files` for
`mapchooser.cfg` and `rtv.cfg`. An `autoexec_cfg_stub = "<name>.cfg"` attribute
would replace that.

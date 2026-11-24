# Addon Packaging

## Goal

One label per addon should carry everything the addon installs, with paths
relative to the game-mod root (such as `cstrike/`). The same label should work
in both places addons are consumed:

- **Release archives**: a `pkg_tar` / `pkg_zip` unpacked over a game directory.
- **Server image layers**: a `pkg_tar` combining many addons, as in
  [counterstrikesource-server](https://github.com/kleinpa/counterstrikesource-server/blob/main/BUILD.bazel).
  The server repo should not need to know which extra files a plugin uses.

## Who owns an install path

If a compile rule generates the file, that rule owns its path. If someone wrote
the file by hand, the addon does.

`sourcemod_plugin` and `sourcemod_extension` already work this way: they output
the compiled file plus a `PackageFilesInfo` saying where it installs. This should
stay, because:

- Only the rule knows the path. An extension's depends on the CPU
  (`extensions/x64`) and its name on the engine (`.ext.2.tf2.so`).
- A single plugin or extension can go straight into `pkg_tar`.
- It's only a default. A plugin can be wrapped in `pkg_files` to install
  elsewhere, such as `plugins/disabled`. Extensions with `autoload` are harder,
  since the `.autoload` file must stay out of `x64/`.

## Proposal: `sourcemod_addon`

Hand-written files currently need `pkg_files` and `pkg_filegroup` for each addon.
Add a macro for them:

```starlark
sourcemod_addon(
    name = "my_addon",
    deps = [
        ":my_extension",
        ":my_plugin",
    ],
    gamedata = ["my_addon.games.txt"],
    translations = glob(["translations/**"]),
    visibility = ["//visibility:public"],
)

pkg_tar(
    name = "my_addon_tar",
    srcs = [":my_addon"],
    extension = "tar.gz",
)
```

| Attribute        | Installs to                                                        |
| ---------------- | ------------------------------------------------------------------ |
| `deps`           | Wherever each plugin, extension, or other addon says               |
| `gamedata`       | `addons/sourcemod/gamedata/`                                       |
| `translations`   | `addons/sourcemod/translations/`, keeping `<lang>/` subdirectories |
| `configs`        | `addons/sourcemod/configs/`                                        |
| `cfgs`           | `cfg/sourcemod/`                                                   |
| `autoexec_stubs` | `cfg/sourcemod/<name>.cfg`, [generated](#autoexecconfig-stubs)     |
| `game_files`     | Mod root: `materials/`, `models/`, `sound/`, `scripts/`, `cfg/`    |

It expands to one `pkg_files` per attribute and a `pkg_filegroup`, so it works
with `pkg_tar`, `pkg_zip`, `platform_transition_pkg`, and other addons.

It doesn't build an archive. Servers combine addons, which shouldn't mean nesting
one tar inside another, and the archive format is the caller's choice.

It replaces the `pkg_filegroup` pattern in [design.md](../design.md#packaging),
which [auth-by-steam-group](https://github.com/lanofdoom/auth-by-steam-group)
already uses.

### Alternative: attributes on the compile rules

Adding these attributes to `sourcemod_plugin` and `sourcemod_extension` would
avoid a new macro, but:

- The files belong to an addon. With an extension and a plugin, it's arbitrary
  which one owns the gamedata.
- Both rules would need the same attributes.
- `PackageFilesInfo` holds one file mode, and extensions install as `0755`, so
  they would have to return `PackageFilegroupInfo` to add `0644` files.

### Open questions

- **Path stripping.** `translations` and `game_files` have to keep
  subdirectories. Should the macro strip a fixed directory, such as
  `translations/`, or take a prefix?

## `AutoExecConfig` stubs

When a plugin calls `AutoExecConfig(true, ...)` and its `cfg/sourcemod/<name>.cfg`
is missing, SourceMod writes one containing the convar defaults and executes it,
overriding values set in `server.cfg`. Shipping a stub file prevents this.

`counterstrikesource-server` does so with `write_file` + `pkg_files` for
`mapchooser.cfg` and `rtv.cfg`. `autoexec_stubs = ["mapchooser", "rtv"]` would
replace that. Stubs need a comment line, because Source 2006 can't `exec` an empty
file (see `hiddensource-server`).

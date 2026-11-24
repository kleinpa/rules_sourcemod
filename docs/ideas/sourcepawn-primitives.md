# SourcePawn Addon Asset & Layer Packaging

## Two Packaging Targets to Serve Simultaneously

Any asset/bundle primitive in `rules_sourcemod` should treat two consumption
models as equal first-class targets:

1. **Community-standard release archives (`pkg_zip` / `pkg_tar`)**:
   - Standalone `.zip` / `.tar.gz` archives unpacked onto a mutable game
     directory (`addons/sourcemod/...`, `cfg/sourcemod/...`, `sound/...`) for
     GitHub Releases or AlliedModders forum distributions.
2. **Declarative Bazel OCI server layers** (as in
   [`kleinpa/counterstrikesource-server/BUILD.bazel`](https://github.com/kleinpa/counterstrikesource-server/blob/main/BUILD.bazel)):
   - Downstream server image repos pull many independent addon modules as Bzlmod
     deps (`@gungame//:plugin`, `@paintball//:plugin`, `@ffa_spawns//:plugin`,
     `@empty_team_bots`, `@override_tickrate//:extension`,
     `@auth_by_steam_group//:{extension,plugin}`) and drop them into a single
     flat `pkg_tar`:
     ```starlark
     pkg_tar(
         name = "plugins_layer",
         srcs = [
             "@ffa_spawns//:plugin",
             "@gungame//:plugin",
             "@override_tickrate//:extension",
             "@paintball//:plugin",
         ],
         package_dir = "/opt/game/cstrike",
     )
     ```
   - Critically, **the server repo should never have to know which auxiliary
     files a plugin needs**. If `@gungame//:plugin` or `@paintball//:plugin`
     needs translations, gamedata, default configs, sounds, or decals, all of
     those paths must travel inside that single target's `rules_pkg` provider
     (`PackageFilesInfo` or `PackageFilegroupInfo`), relative to the game-mod
     root (`cstrike/`).

## Implications for the Rule Design

1. **Carry companion assets directly on `sourcemod_plugin` (or a `sourcemod_addon`
   bundle returning `PackageFilegroupInfo`)**:
   - SourceMod-scoped directories:
     - `gamedata` -> `addons/sourcemod/gamedata/`
     - `translations` -> `addons/sourcemod/translations/` (preserving `<lang>/`
       subdirectories when present)
     - `configs` -> `addons/sourcemod/configs/`
     - `cfgs` -> `cfg/sourcemod/`
   - Game-root asset trees (needed by gameplay mods like `@paintball` /
     `@gungame`):
     - `game_files` (or `data` with strip-prefix) -> `sound/`, `materials/`,
       `models/`, `scripts/` relative to the mod root (`package_dir`).
2. **Composite extension + plugin addons (`PackageFilegroupInfo`)**:
   - Multi-component repos like `@auth_by_steam_group` currently expose separate
     `//:extension` (`0755`) and `//:plugin` (`0644`) targets in the server's
     `pkg_tar`. A `sourcemod_addon` rule/macro wrapping `pkg_filegroup` (and
     compatible with `platform_transition_pkg`) lets an addon repo expose a
     single `@auth_by_steam_group` target carrying its `.ext`, `.smx`, and data
     files with their respective file modes preserved, while still working
     identically in both `pkg_tar(package_dir = "/opt/game/cstrike")` OCI layers
     and standalone `pkg_zip` release archives.
3. **Immutable container `cfg/sourcemod/*.cfg` ergonomics**:
   - In `counterstrikesource-server`, plugins that call `AutoExecConfig(true, ...)`
     generate missing `cfg/sourcemod/<name>.cfg` files on first boot and clobber
     convars already set in `server.cfg` unless an empty (or explicit) `.cfg`
     sentinel is shipped in the image layer. Making `cfgs` (or an opt-in empty
     `autoexec_cfg_stub = "<name>.cfg"`) trivial to attach on the plugin/layer
     side avoids hand-rolling `write_file` + `pkg_files` workarounds per plugin.

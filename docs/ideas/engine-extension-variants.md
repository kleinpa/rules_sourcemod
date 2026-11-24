# Multi-Branch `sourcemod_hl2_extension` Macro

Upstream AMBuild's `SM.HL2ExtConfig` compiles one extension source tree across a
list of HL2SDK branches so a single release archive can ship
`<name>.ext.2.css.<so|dll>`, `<name>.ext.2.tf2.<so|dll>`, etc. side-by-side in
`addons/sourcemod/extensions[/x64]/` (SourceMod's `ExtensionSys` probes the
active engine's `.ext.<engine>` binary first at startup).

If multi-game extension authors need a convenience wrapper over per-branch
`sourcemod_extension(..., branch = "<branch>")` targets, a thin macro can layer
directly on top:

```starlark
sourcemod_hl2_extension(
    name = "my_ext",
    branches = ["css", "tf2", "l4d2", "sdk2013"],
    autoload = True,
    srcs = ["extension.cpp"],
    hdrs = ["extension.h", "smsdk_config.h"],
)
```

## Multi-Platform Packaging Nuance

Because `css` and `tf2` support 64-bit targets while `l4d2` and `sdk2013` are
32-bit-only (and `ep1` is 32-bit Windows-only), a plain `pkg_filegroup` without
platform transitions only collects branches compatible with the active
`--platforms`. Multi-architecture release archives should compose the generated
`:my_ext_<branch>` targets through `platform_transition_pkg` so the CPU/OS
transitions remain explicit.

# Multi-Branch Extensions

Extensions that use engine APIs are compiled once per HL2SDK branch and shipped
side by side as `<name>.ext.<engine>.<so|dll>`. SourceMod loads the file matching
the running engine, falling back to `<name>.ext.<so|dll>`. Upstream builds these
from one source tree with `SM.HL2ExtConfig`; `sourcemod_extension` accepts only
one `branch`, so authors repeat the target for each.

## Proposed macro

```starlark
sourcemod_hl2_extension(
    name = "my_ext",
    branches = ["css", "tf2", "l4d2", "sdk2013"],
    autoload = True,
    srcs = ["extension.cpp"],
    hdrs = ["extension.h", "smsdk_config.h"],
)
```

It would generate:

- `:my_ext_<branch>`: a complete `sourcemod_extension` for one branch, including
  `.autoload`, for single-engine servers.
- `:my_ext`: a `pkg_filegroup` of the branches with one `.autoload`.
- `:my_ext_inc`: one `sourcemod_library` for `pawn_hdrs`.

## Packaging constraints

**Incompatible branches.** A `pkg_filegroup` containing an incompatible target is
itself incompatible. `css` and `tf2` build for 32-bit and 64-bit, `l4d2` and
`sdk2013` only for 32-bit, and `ep1` only for 32-bit Windows, so a plain
`:my_ext` with the branches above could not be built for x86_64 at all. Either:

- `select()` the members of `:my_ext` by platform, or
- for a release archive covering several platforms, wrap each `:my_ext_<branch>`
  in `platform_transition_pkg`.

**Duplicate `.autoload` files.** Every branch and platform installs the same
`addons/sourcemod/extensions/<name>.autoload`. Branches in one package and
configuration share the generated file, so they combine cleanly. Across packages
or platform transitions, the files have different source paths:

- By default, `pkg_tar` and `pkg_zip` print a `Duplicate output path` warning.
- With `allow_duplicates_with_different_content = False`, the build fails.

The macro should therefore emit `.autoload` once, outside the per-branch members
of `:my_ext` and outside any platform transition.

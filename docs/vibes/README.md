# Ideas

Unimplemented proposals for `rules_sourcemod`. Upstream facts refer to the
commits pinned in `sourcemod/repositories.bzl` and `hl2sdk/repositories.bzl`
unless noted.

| Area              | Document                                                       | Proposal                                                   |
| ----------------- | -------------------------------------------------------------- | ---------------------------------------------------------- |
| Addon authoring   | [addon-packaging.md](addon-packaging.md)                       | Ship gamedata, configs, and assets with an addon target    |
| Addon authoring   | [engine-extension-variants.md](engine-extension-variants.md)   | Build one extension for several engine branches            |
| Addon authoring   | [better-examples.md](better-examples.md)                       | Standalone consumer workspace, also used as a CI test      |
| Developer tooling | [sourcemod-test-natives.md](sourcemod-test-natives.md)         | Call SourceMod natives in `sourcemod_test`                 |
| Developer tooling | [sourcepawn-lsp.md](sourcepawn-lsp.md)                         | Generate editor config for SourcePawn Studio               |
| Server builds     | [all-branches.md](all-branches.md)                             | Support the remaining Source 1 HL2SDK branches             |
| Server builds     | [build-parity.md](build-parity.md)                             | Missing extensions, Linux symbol hiding, Windows resources |
| Toolchains        | [platform-quirks.md](platform-quirks.md)                       | Windows warnings, toolchain cleanup, non-x86 hosts         |

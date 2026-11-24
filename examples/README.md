# Examples

- [`plugin`](plugin): a plugin that adds bots when few people are playing.
- [`extension`](extension): an extension and plugin, packaged together, that ask
  an HTTPS endpoint who may join.
- [`cross`](cross): a Windows server layer, including the extension, built on
  Linux.

Run from this directory:

```console
$ bazel build //plugin //extension:all
$ bazel build --config=cross-windows //cross:sourcemod_layer //cross:metamod_vdf_layer
```

The cross build downloads the Windows SDK; see the license note in
[`MODULE.bazel`](MODULE.bazel).

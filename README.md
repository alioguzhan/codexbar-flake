# codexbar-flake

Nix flake for the [CodexBar](https://github.com/steipete/CodexBar) CLI on Linux.

CodexBar is a macOS menu bar app; upstream also publishes a standalone Linux CLI
as a release binary. This flake packages that binary. It does not build from
source.

## Use it

```nix
{
  inputs.codexbar.url = "github:alioguzhan/codexbar-flake";
  inputs.codexbar.inputs.nixpkgs.follows = "nixpkgs";
}
```

```nix
# NixOS or home-manager
home.packages = [ inputs.codexbar.packages.${pkgs.system}.default ];
```

Or without installing:

```console
$ nix run github:alioguzhan/codexbar-flake -- usage --provider claude
```

Bump it with `nix flake update codexbar`.

## How it is packaged

Upstream ships four Linux tarballs per release. This takes the **static musl**
one, so the derivation needs no `autoPatchelfHook` and pins no runtime
libraries — a nixpkgs bump of curl, sqlite or libstdc++ cannot break it. The
cost is that the vendored curl and openssl only pick up CVE fixes when upstream
cuts a new release.

Two details the packaging has to get right, both verified by
`installCheckPhase`:

- `CodexBarCLI` resolves `CodexBar_CodexBarCore.bundle` (the JavaScript provider
  plugins) and `VERSION` relative to `/proc/self/exe`. Installing only the
  executable leaves a binary that reports `CodexBar unknown` and cannot run its
  plugin-backed providers. So the whole payload goes to
  `$out/libexec/codexbar/` and `$out/bin/codexbar` is a symlink into it.
- The released binary carries debug info: 242 MiB in the store. `stdenvNoCC`
  does not strip, so the derivation strips explicitly — 81 MiB.

## Updates

`update.sh` reads the latest upstream release and rewrites `release.json`,
taking hashes from the `.sha256` sidecars upstream publishes (so it never
downloads the tarballs). `.github/workflows/update.yml` runs it every 6 hours,
**builds the result**, and only then commits to `main`. A release that fails to
build fails the workflow instead of landing.

Run it by hand with `nix develop -c ./update.sh`.

## Platforms

`x86_64-linux` and `aarch64-linux`. Only `x86_64-linux` is exercised by CI.

## License

The packaging in this repository is MIT. CodexBar itself is MIT, © Peter Steinberger.

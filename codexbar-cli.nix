{ lib, stdenvNoCC, fetchurl, binutils }:

let
  # Version and per-system hashes live in release.json so the updater rewrites
  # structured data instead of pattern-matching Nix source.
  release = builtins.fromJSON (builtins.readFile ./release.json);

  system = stdenvNoCC.hostPlatform.system;

  # Upstream names the musl assets by CPU, not by Nix system tuple.
  cpus = {
    "x86_64-linux" = "x86_64";
    "aarch64-linux" = "aarch64";
  };

  cpu = cpus.${system} or (throw "codexbar-cli: no Linux musl release for ${system}");
  hash = release.hashes.${system} or (throw "codexbar-cli: no hash recorded for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "codexbar-cli";
  version = release.version;

  # Of the four Linux tarballs upstream publishes, this takes the musl one: a
  # fully static ELF with no interpreter, so no autoPatchelfHook and no runtime
  # library pins — nothing here breaks when nixpkgs bumps the curl, sqlite or
  # libstdc++ sonames. The trade-off is that the vendored curl/openssl only get
  # CVE fixes with a new upstream release. Upstream releases near-daily.
  src = fetchurl {
    url = "https://github.com/steipete/CodexBar/releases/download/v${release.version}/CodexBarCLI-v${release.version}-linux-musl-${cpu}.tar.gz";
    inherit hash;
  };

  sourceRoot = ".";

  # stdenvNoCC has no strip in its fixup phase, and upstream ships the binary
  # with debug_info: 242 MiB in the store unstripped, 81 MiB stripped.
  nativeBuildInputs = [ binutils ];

  # CodexBarCLI resolves `CodexBar_CodexBarCore.bundle` (the JS provider
  # plugins: openai, poe, xai, zai, openrouter, ...) and `VERSION` next to its
  # own binary, via /proc/self/exe. Installing only the executable silently
  # degrades it — `--help` then reports "CodexBar unknown". So the payload goes
  # to libexec as a unit and bin/ gets a symlink; /proc/self/exe follows the
  # symlink to libexec, where the siblings are.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/codexbar $out/bin
    cp -r CodexBarCLI VERSION CodexBar_CodexBarCore.bundle $out/libexec/codexbar/
    chmod +x $out/libexec/codexbar/CodexBarCLI
    strip $out/libexec/codexbar/CodexBarCLI
    ln -s ../libexec/codexbar/CodexBarCLI $out/bin/codexbar

    runHook postInstall
  '';

  # Guards both failure modes above: a stripped Swift static binary that no
  # longer runs, and a lost resource bundle (which shows up as "unknown").
  # This is also the gate the update workflow runs before committing a bump.
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/codexbar --help | grep -q "CodexBar ${release.version}"
  '';

  meta = {
    description = "Track Codex, Claude, Cursor, Gemini and other AI provider usage limits";
    homepage = "https://github.com/steipete/CodexBar";
    license = lib.licenses.mit;
    platforms = builtins.attrNames cpus;
    mainProgram = "codexbar";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}

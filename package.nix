{ pkgs, ... }:

let
  pnpm = pkgs.pnpm_10;
  nodejs = pkgs.nodejs_22;
in
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openclaw";
  version = "2026.3.28";

  src = pkgs.fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    rev = "v${finalAttrs.version}";
    hash = "sha256-mv1G9AWo/aGrJZGLE5mbvQrJDEgfvuvBlDBfi7EPnbc=";
  };

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-Kcuh8LdTCF9/d36eo/DtqN9zQwWWOYlrNz7c1gem1FY=";
    fetcherVersion = 2;
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpm.configHook
    pkgs.makeWrapper
    pkgs.git
    pkgs.jq
  ];

  buildInputs = with pkgs; [
    vips
    sqlite
  ];

  env = {
    OPENCLAW_NIX_MODE = "1";

    # Skip llama.cpp source compilation
    NODE_LLAMA_CPP_SKIP_DOWNLOAD = "true";
    LLAMA_CPP_SKIP_DOWNLOAD = "true";

    # Use system vips for sharp
    SHARP_IGNORE_GLOBAL_LIBVIPS = "0";
    PKG_CONFIG_PATH = "${pkgs.vips.dev}/lib/pkgconfig";

    # Native module library paths
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.libopus}/lib:${pkgs.glibc}/lib";

    # Skip browser downloads
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  postPatch = ''
    # Remove packageManager field to avoid corepack version mismatch
    ${pkgs.jq}/bin/jq 'del(.packageManager)' package.json > package.json.tmp
    mv package.json.tmp package.json

    # Skip stageBundledPluginRuntimeDeps — it runs npm install per plugin
    # (discord, slack, feishu, telegram) which fails in the sandbox.
    # The deps are available via pnpm's node_modules linking.
    sed -i 's/stageBundledPluginRuntimeDeps(params)/void 0/' scripts/runtime-postbuild.mjs
  '';

  buildPhase = ''
    runHook preBuild
    pnpm build
    pnpm ui:build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/openclaw $out/bin

    cp -r dist node_modules package.json $out/lib/openclaw/

    # Remove broken symlinks (workspace packages not in output)
    find $out/lib/openclaw/node_modules -type l ! -exec test -e {} \; -delete

    makeWrapper ${nodejs}/bin/node $out/bin/openclaw \
      --add-flags "$out/lib/openclaw/dist/index.js" \
      --suffix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.glibc pkgs.libopus ]}" \
      --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.bash ]}" \
      --set OPENCLAW_NIX_MODE 1

    runHook postInstall
  '';

  meta = {
    description = "A personal AI assistant you run on your own devices";
    homepage = "https://github.com/openclaw/openclaw";
    license = pkgs.lib.licenses.mit;
    mainProgram = "openclaw";
  };
})

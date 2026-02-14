{ pkgs, ...}:

pkgs.buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.2.13";

  src = pkgs.fetchFromGitHub {
    owner = "openclaw";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-XTMnZJwnDqAsM1Wm4zELUEm/+LBzxAPz/O3sBsLfuSo=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json

    # Remove packageManager field and add npm workspaces (to match pnpm-workspace.yaml)
    ${pkgs.jq}/bin/jq 'del(.packageManager) | . + {"workspaces": ["ui", "packages/*", "extensions/*"]}' package.json > package.json.tmp
    mv package.json.tmp package.json

    # Replace pnpm workspace:* protocol with * (npm doesn't understand workspace:)
    find . -name "package.json" -exec sed -i 's/"workspace:\*"/"*"/g' {} \;
  '';

  nodejs = pkgs.nodejs_24;

  npmDepsHash = "sha256-NvVA/sg55Bp0AsLY6Zzijfm9szyteQB/2HBn8y5wN8k=";

  makeCacheWritable = true;

  # Runtime dependencies for openclaw
  buildInputs = with pkgs; [
    vips          # For sharp image processing
    sqlite        # For vector embeddings
  ];

  nativeBuildInputs = with pkgs; [
    git
    python3
    pkg-config
    nodePackages.pnpm  # Build scripts use pnpm commands
  ];

  # Environment configuration
  env = {
    OPENCLAW_NIX_MODE = "1";

    # Skip node-llama-cpp download/build entirely (use external API instead)
    NODE_LLAMA_CPP_SKIP_DOWNLOAD = "true";
    LLAMA_CPP_SKIP_DOWNLOAD = "true";

    # Help sharp use system vips instead of building from source
    SHARP_IGNORE_GLOBAL_LIBVIPS = "0";
    PKG_CONFIG_PATH = "${pkgs.vips.dev}/lib/pkgconfig";

    # Help native modules find libraries
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";

    # Disable pnpm strict version checking (can't download in sandbox)
    COREPACK_ENABLE_STRICT = "0";
    PNPM_HOME = "/build/.pnpm";
  };

  # openclaw uses pnpm, but we provide a vendored package-lock.json
  # generated from the package.json for reproducible builds

  npmPackFlags = [ "--ignore-scripts" ];

  # UI build. package-lock.json has all workspace dependencies
  postBuild = ''
    pnpm ui:build
  '';

  # Remove broken workspace symlinks created by npm workspaces
  # These point to local packages that aren't part of the final output
  preFixup = ''
    find $out -type l ! -exec test -e {} \; -delete
  '';

  meta = {
    description = "A personal AI assistant you run on your own devices";
    homepage = "https://github.com/openclaw/openclaw";
    license = pkgs.lib.licenses.mit;
    mainProgram = "openclaw";
  };
}

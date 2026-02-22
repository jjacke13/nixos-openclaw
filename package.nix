{ pkgs, ...}:

pkgs.buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.2.21";

  src = pkgs.fetchFromGitHub {
    owner = "openclaw";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-iV/n217XAkFaMdoYhBKoSthwmCYr2XzGcp7V4pVF008=";
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

  npmDepsHash = "sha256-QvzhxdXVmxabsI/Nni7DQuXkJ1p+FBUL1TXdrFxcFxM=";

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
    makeWrapper        # For wrapping the binary with runtime env vars
  ];

  # Environment configuration
  env = {
    OPENCLAW_NIX_MODE = "1";

    # llama-cpp modules are included in the resulting package
    # If these variables are not set, nix tries to compile from scratch the llama-cpp modules
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

  # Environment variables needed at runtime
  # LD_LIBRARY_PATH needed so local memory embedding models can be run
  # coreutils and bash are needed in the PATH so the agent can run basic commands
  postFixup = ''
    wrapProgram $out/bin/openclaw \
      --suffix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.glibc ]}" \
      --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.bash ]}" \
      --set OPENCLAW_NIX_MODE 1
  '';

  meta = {
    description = "A personal AI assistant you run on your own devices";
    homepage = "https://github.com/openclaw/openclaw";
    license = pkgs.lib.licenses.mit;
    mainProgram = "openclaw";
  };
}

{ lib, stdenvNoCC, fetchFromGitHub, bun, nodejs, makeWrapper, git }:

let
  version = "2.2.23";

  src = fetchFromGitHub {
    owner = "sirmalloc";
    repo = "ccstatusline";
    rev = "v${version}";
    hash = "sha256-Aqy9m/PtD50FRRpOHFhqI398dKM0iDriCsy+OEgdCpY=";
  };

  # Fixed-output derivation: bun install → node_modules (네트워크 허용, 해시로 고정)
  node_modules = stdenvNoCC.mkDerivation {
    pname = "ccstatusline-node-modules";
    inherit version src;

    nativeBuildInputs = [ bun ];
    dontConfigure = true;

    buildPhase = ''
      export HOME=$TMPDIR
      bun install --frozen-lockfile --no-progress --ignore-scripts
    '';

    installPhase = ''
      cp -r node_modules $out
    '';

    dontFixup = true;
    outputHashMode = "recursive";
    outputHash = "sha256-mbZr8idcvzzamAWrXW+4xM/0PXmFEZkGL4sySaebvIk=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "ccstatusline";
  inherit version src;

  nativeBuildInputs = [ bun makeWrapper ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    cp -r ${node_modules} node_modules
    chmod -R u+w node_modules
    bun build src/ccstatusline.ts --target=node --outfile=dist/ccstatusline.js
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp dist/ccstatusline.js $out/lib/ccstatusline.js
    makeWrapper ${nodejs}/bin/node $out/bin/ccstatusline \
      --add-flags $out/lib/ccstatusline.js \
      --prefix PATH : ${lib.makeBinPath [ git ]}
    runHook postInstall
  '';

  meta = {
    description = "Highly customizable statusline for Claude Code (sirmalloc/ccstatusline), pinned via Nix";
    homepage = "https://github.com/sirmalloc/ccstatusline";
    license = lib.licenses.mit;
    mainProgram = "ccstatusline";
  };
}

nix-build --option sandbox false --cores 1


install them in your shell with:

nix-env -iA nixpkgs.nix-prefetch-github

nix-prefetch-github valhalla valhalla --rev 3.5.1
nix-prefetch-github HowardHinnant date --rev v3.0.1



date = stdenv.mkDerivation {
    pname = "date";
    version = "3.0.1";

    src = fetchFromGitHub {
    owner = "valhalla";
    repo = "valhalla";
    rev = "d377c8ace9ea88dfa989466258bf738b1080f22a";
    sha256 = "sha256-v/EwoJA1j8PuF9jOsmxQL6i+MT0rXbyLUE4HvBHUWDo=";  
    fetchSubmodules = true;
  };




  protoVersion = "3.3.0";  # Match protobuf version with Valhalla 3.3.0
  protobufCustom = stdenv.mkDerivation {
    pname = "protobuf";
    version = protoVersion;

    src = fetchFromGitHub {
      owner = "protocolbuffers";
      repo = "protobuf";
      rev = "v${protoVersion}";
      sha256 = "sha256-PJVYMRGwYvtj+m0rbontjEPL5xFi/zgg18p76tL3qIg=";
    };
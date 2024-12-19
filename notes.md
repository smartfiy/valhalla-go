nix-build --option sandbox false --cores 1


# Clean nix store
nix-store --gc

# Clean nix store (may need sudo)
nix-collect-garbage -d

install them in your shell with:

nix-env -iA nixpkgs.nix-prefetch-github

nix-prefetch-github valhalla valhalla --rev 3.5.1
nix-prefetch-github HowardHinnant date --rev v3.0.1
nix-prefetch-github nixos nixpkgs --rev 23.11



# Run tests with explicit library paths
export LD_LIBRARY_PATH="$PWD/result/lib:${LD_LIBRARY_PATH}"
export CGO_LDFLAGS="-L$PWD/result/lib -lvalhalla_go"
export CGO_CFLAGS="-I$PWD/bindings"

# Run tests with verbose output
go test -v -x



# Check the library dependencies
ldd --version
ldd result/lib/libvalhalla_go.so

# Check if there are any undefined symbols
nm -D result/lib/libvalhalla_go.so | grep GLIBC


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
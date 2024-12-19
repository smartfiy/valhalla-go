{ nixpkgs ? import <nixpkgs> {}, stdenv, fetchFromGitHub, cmake, pkg-config }:

with nixpkgs;

stdenv.mkDerivation rec {
  name = "valhalla";
  version = "3.5.1";

  src = fetchFromGitHub {
    owner = "valhalla";
    repo = "valhalla";
    rev = "d377c8ace9ea88dfa989466258bf738b1080f22a";
    sha256 = "sha256-v/EwoJA1j8PuF9jOsmxQL6i+MT0rXbyLUE4HvBHUWDo=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    protobuf
  ];

  buildInputs = [
    boost179
    protobuf
    zlib
    sqlite
    libspatialite
    lua5_3
    geos
    curl
    openssl
    libpqxx
    libxml2
    lz4
    prime-server
    jemalloc
  ];

  # Use older GLIBC features
  NIX_CFLAGS_COMPILE = toString [
    "-D_GNU_SOURCE"
    "-D_DEFAULT_SOURCE"
    "-DGLIBC_COMPAT"
    "-fPIC"
    "-I${protobuf}/include"
    "-I${src}/third_party/rapidjson/include"
  ];

  CFLAGS = "-O2 -D_FORTIFY_SOURCE=2";
  LDFLAGS = "-Wl,--as-needed -Wl,-z,relro";

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DENABLE_TOOLS=OFF"
    "-DENABLE_DATA_TOOLS=OFF"
    "-DENABLE_SERVICES=OFF"
    "-DENABLE_API_DOC=OFF"
    "-DENABLE_PYTHON_BINDINGS=OFF"
    "-DENABLE_COVERAGE=OFF"
    "-DENABLE_COMPILER_WARNINGS=OFF"
    "-DENABLE_WERROR=OFF"
    "-DENABLE_BENCHMARKS=OFF"
    "-DENABLE_TESTS=OFF"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-DBUILD_SHARED_LIBS=ON"
    "-DProtobuf_INCLUDE_DIR=${protobuf}/include"
    "-DProtobuf_LIBRARIES=${protobuf}/lib/libprotobuf${stdenv.hostPlatform.extensions.sharedLibrary}"
  ];

  CXXFLAGS = [
    "-I${protobuf}/include"
    "-I${src}/third_party/rapidjson/include"
    
  ];

  postInstall = ''
    # Copy third-party headers maintaining directory structure
    mkdir -p $out/include
    cp -r $src/third_party/rapidjson/include/* $out/include/
    cp -r $src/third_party/date/include/* $out/include/
    cp -r $src/third_party/robin-hood-hashing/src/include/* $out/include/

    
  '';

  propagatedBuildInputs = [
    protobuf
  ];
}
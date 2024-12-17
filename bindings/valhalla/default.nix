{ nixpkgs ? import <nixpkgs> {}, stdenv, fetchFromGitHub, cmake, pkg-config }:

with nixpkgs;

stdenv.mkDerivation rec {
  name = "valhalla";

  src = fetchFromGitHub {
    owner = "valhalla";
    repo = "valhalla";
    rev = "d377c8ace9ea88dfa989466258bf738b1080f22a";
    sha256 = "sha256-C/2w3jmhMRLUW7vGo49NqoXSrmWIalH2yKVx7saxM68=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    git
  ];

  cmakeFlags = [
    "-DENABLE_CCACHE=OFF"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DENABLE_BENCHMARKS=OFF"
    "-DENABLE_PYTHON_BINDINGS=OFF"
    "-DENABLE_TESTS=OFF"
    "-DENABLE_TOOLS=OFF"
    "-DENABLE_SERVICES=OFF"
    "-DENABLE_HTTP=OFF"
    "-DENABLE_CCACHE=OFF"
    "-DENABLE_DATA_TOOLS=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-DCMAKE_INCLUDE_PATH=${src}/third_party/robin-hood-hashing/src/include"
  ];

  # Instead of symlinks, we'll add to CXXFLAGS
  NIX_CXXFLAGS_COMPILE = toString [
    "-I${src}/third_party/robin-hood-hashing/src/include"
    "-I${src}/third_party/rapidjson/include"
    "-I${src}/third_party/date/include"
  ];

  buildInputs = [
    zlib
    boost179
    protobuf
    sqlite
    libspatialite
    luajit
    geos
    curl
    openssl
    libpqxx
    libxml2
    lz4
    prime-server
    jemalloc
  ];

  # Set up environment variables
  preConfigure = ''
    export BOOST_ROOT=${boost179}
    export SQLITE_ROOT=${sqlite.dev}
  '';

  postInstall = ''
    mkdir -p $out/include
    cp -r $src/third_party/robin-hood-hashing/src/include/* $out/include/
    cp -r $src/third_party/rapidjson/include/* $out/include/
    cp -r $src/third_party/date/include/* $out/include/
  '';
}
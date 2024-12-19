{ nixpkgs ? import <nixpkgs> {}
, lib
, stdenv
, abseil-cpp
, cmake
, fetchFromGitHub
, fetchpatch
, gtest
, zlib
, pkg-config
, python3
, glibc 
, ...
}:

with nixpkgs;

let
  valhallaCustom = (import ./valhalla) { inherit stdenv fetchFromGitHub cmake pkg-config; };
  protobufCustom = (import ./protobuf) { inherit lib abseil-cpp stdenv fetchFromGitHub cmake fetchpatch gtest zlib python3; };

  # Create a new stdenv with gcc12
  gcc12Stdenv = stdenv.override {
    cc = gcc12;
    bintools = nixpkgs.buildPackages.binutils.override {
      bintools = nixpkgs.buildPackages.binutils;
    };
  };
in stdenv.mkDerivation {
  name = "valhalla-go";
  version = "0.1.0";
  src = ./..;

  nativeBuildInputs = [ cmake pkg-config ];
  
  buildInputs = [
    stdenv.cc.cc.lib
    gcc12
    boost179
    valhallaCustom
    protobuf
    zlib
    protobufCustom
  ];

  
  # Force the use of gcc12
  shellHook = ''
    export CC=${pkgs.gcc12}/bin/gcc
    export CXX=${pkgs.gcc12}/bin/g++
  '';
  
  # Ensure the linker can find the libraries
  NIX_LDFLAGS = "-L${pkgs.stdenv.cc.cc.lib}/lib";
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";

  dontConfigure = true;
  NIX_CFLAGS_COMPILE = "-Wno-deprecated-builtins -fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -D_GNU_SOURCE -O2"; 
  

  # Set environment variables to ensure compatible GLIBC version
  CFLAGS = "-O2 -D_FORTIFY_SOURCE=2";
  CXXFLAGS = "-O2 -D_FORTIFY_SOURCE=2";
  LDFLAGS = "-Wl,--as-needed -Wl,-z,relro";

    # Disable hardening to avoid GLIBC version conflicts
  hardeningDisable = [ "fortify" "stackprotector" ];

  # Environment setup
  preBuild = ''
    export CC=${gcc12}/bin/gcc
    export CXX=${gcc12}/bin/g++
    export CXXFLAGS="$CXXFLAGS -I${valhallaCustom}/include -I${protobufCustom}/include"
    export LDFLAGS="$LDFLAGS -L${valhallaCustom}/lib -L${protobufCustom}/lib"
    export LD_LIBRARY_PATH="${valhallaCustom}/lib:${protobufCustom}/lib:${stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
  '';

  buildPhase = ''
    export CC=gcc
    export CXX=g++
    mkdir -p build
    cd build
    
    $CXX ../bindings/valhalla_go.cpp \
      -fPIC \
      -shared \
      -o libvalhalla_go.so \
      -I${valhallaCustom}/include \
      -I${protobuf}/include \
      -I${valhallaCustom}/include/rapidjson \
      -L${valhallaCustom}/lib \
      -L${protobuf}/lib \
      -Wl,-rpath,${valhallaCustom}/lib \
      -Wl,-rpath,${protobuf}/lib \
      -Wl,--hash-style=gnu \
      -Wl,--dynamic-linker=${glibc}/lib/ld-linux-x86-64.so.2 \
      -lvalhalla \
      -lprotobuf \
      -lz \
      -lpthread \
      -std=c++17
  '';

  # Ensure proper library paths and older GLIBC symbols
  postFixup = ''
    patchelf --set-rpath "${stdenv.cc.cc.lib}/lib:${valhallaCustom}/lib:${protobuf}/lib" $out/lib/libvalhalla_go.so
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp libvalhalla_go.so $out/lib/
  '';

  # Ensure paths are properly set
  preFixup = ''
    patchelf --set-rpath "${stdenv.cc.cc.lib}/lib:${valhallaCustom}/lib:${protobufCustom}/lib" $out/lib/libvalhalla_go.so
  '';

  meta = with lib; {
    description = "Go bindings for Valhalla routing engine";
    platforms = platforms.unix;
  };
}
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
, ...
}:

with nixpkgs;

let
  valhallaCustom = (import ./valhalla) { inherit stdenv fetchFromGitHub cmake pkg-config; };
  protobufCustom = (import ./protobuf) { inherit lib abseil-cpp stdenv fetchFromGitHub cmake fetchpatch gtest zlib python3; };
in stdenv.mkDerivation {
  name = "valhalla-go";
  version = "0.1.0";
  src = ./..;

  nativeBuildInputs = [ pkg-config ];
  
  buildInputs = [
    stdenv.cc.cc.lib
    boost179
    valhallaCustom
    protobuf
    zlib
    protobufCustom
  ];

  dontConfigure = true;

  NIX_CFLAGS_COMPILE = "-Wno-deprecated-builtins -fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -D_GNU_SOURCE"; 
  hardeningDisable = [ "fortify" ];

  # Set environment variables to ensure compatible GLIBC version
  CFLAGS = "-O2 -D_FORTIFY_SOURCE=2";
  CXXFLAGS = "-O2 -D_FORTIFY_SOURCE=2";
  LDFLAGS = "-Wl,--as-needed -Wl,-z,relro";

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
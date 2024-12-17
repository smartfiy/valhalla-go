{ nixpkgs ? import <nixpkgs> {}
, lib
, stdenv
, abseil-cpp
, cmake
, fetchFromGitHub
, fetchpatch
, gtest
, zlib
, pkg-config  # Added 
, python3
, ...
}:

with nixpkgs;

let
  valhallaCustom = (import ./valhalla) { inherit stdenv fetchFromGitHub cmake pkg-config; };
  protobufCustom = (import ./protobuf) { inherit lib abseil-cpp stdenv fetchFromGitHub cmake fetchpatch gtest zlib python3; };
in stdenv.mkDerivation rec {
  name = "valhalla-go";
  version = "./.";

  nativeBuildInputs = [ cmake pkg-config ];
  
  buildInputs = [
    boost179
    valhallaCustom
    zlib
    protobufCustom
  ];

  # Add flags to handle the deprecated builtins warning
  NIX_CFLAGS_COMPILE = "-Wno-deprecated-builtins";

buildPhase = ''
  c++ \
    valhalla_go.cpp \
    -fPIC \
    -shared \
    -o libvalhalla_go.so \
    -I${protobufCustom}/include \
    -L${protobufCustom}/lib \
    -L${valhallaCustom}/lib \
    -lvalhalla \
    -lprotobuf-lite \
    -lz \
    -lpthread
'';

  installPhase = ''
    mkdir -p $out/lib
    cp libvalhalla_go.so $out/lib
  '';

  meta = with lib; {
    description = "Go bindings for Valhalla routing engine";
    platforms = platforms.unix;
  };
}
{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  valhallaCustom = callPackage ./valhalla {
    inherit stdenv fetchFromGitHub cmake pkg-config;
  };
in
stdenv.mkDerivation {
  name = "valhalla-go";
  version = "0.1.0";
  src = ./..;

  nativeBuildInputs = [ pkg-config ];
  
  buildInputs = [
    boost179
    valhallaCustom
    protobuf
    zlib
  ];

  dontConfigure = true;

  buildPhase = ''
    mkdir -p build
    cd build
    
    c++ ../bindings/valhalla_go.cpp \
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
      -lvalhalla \
      -lprotobuf \
      -lz \
      -lpthread \
      -std=c++17
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp libvalhalla_go.so $out/lib/
  '';

  meta = with lib; {
    description = "Go bindings for Valhalla routing engine";
    platforms = platforms.unix;
  };
}
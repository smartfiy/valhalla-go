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

  NIX_CFLAGS_COMPILE = "-D_GNU_SOURCE -D_DEFAULT_SOURCE -DGLIBC_COMPAT"; # avoid compiling with GLIBC_2.38

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

  meta = with lib; {
    description = "Go bindings for Valhalla routing engine";
    platforms = platforms.unix;
  };
}
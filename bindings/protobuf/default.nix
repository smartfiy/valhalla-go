{ lib
, stdenv
, abseil-cpp
, cmake
, fetchFromGitHub
, fetchpatch
, gtest
, zlib
, python3
, ...
}:

let
  version = "3.21.8";
  self = stdenv.mkDerivation {
    name = "protobuf";
    inherit version;
  
    src = fetchFromGitHub {
      owner = "protocolbuffers";
      repo = "protobuf";
      rev = "v${version}";
      sha256 = "sha256-cSNHX18CvMmydpYWqfe6WWk9rGxIlFfY/85rfSyznU4=";
    };
  
    postPatch = ''
      rm -rf gmock
      cp -r ${gtest.src}/googlemock third_party/gmock
      cp -r ${gtest.src}/googletest third_party/
      chmod -R a+w third_party/
      ln -s ../googletest third_party/gmock/gtest
      ln -s ../gmock third_party/googletest/googlemock
      ln -s $(pwd)/third_party/googletest third_party/googletest/googletest
    '' + lib.optionalString stdenv.isDarwin ''
      substituteInPlace src/google/protobuf/testing/googletest.cc \
        --replace 'tmpnam(b)' '"'$TMPDIR'/foo"'
    '';
  
    nativeBuildInputs = [ cmake ];
  
    buildInputs = [ abseil-cpp zlib ];
  
    cmakeFlags = [
      "-Dprotobuf_ABSL_PROVIDER=package"
      "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
      "-Dprotobuf_BUILD_TESTS=OFF"
      "-DBUILD_SHARED_LIBS=ON"
      "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_SKIP_BUILD_RPATH=ON"
    ];
  
    doCheck = false;

    # Ensure the CMake files are installed in the correct location
    preConfigure = ''
      cmakeDir=$NIX_BUILD_TOP/source
    '';

    # Fix the CMake config files installation
    postInstall = ''
      mkdir -p $out/lib/cmake/protobuf
      cp $NIX_BUILD_TOP/source/*.cmake $out/lib/cmake/protobuf/ || true
      cp $NIX_BUILD_TOP/source/CMakeFiles/Export/lib/cmake/protobuf/* $out/lib/cmake/protobuf/ || true
    '';
  
    passthru = {
      tests = {
        pythonProtobuf = python3.pkgs.protobuf.override(_: {
          protobuf = self;
        });
      };
    };
  
    meta = {
      description = "Google's data interchange format";
      license = lib.licenses.bsd3;
      platforms = lib.platforms.unix;
      homepage = "https://developers.google.com/protocol-buffers/";
    };
  };
in
  self
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
in
stdenv.mkDerivation {
  pname = "protobuf";
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
    "-Dprotobuf_BUILD_SHARED_LIBS=ON"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  configurePhase = ''
    # Create build directory
    mkdir -p $NIX_BUILD_TOP/build
    cd $NIX_BUILD_TOP/build
    
    # Run cmake from build directory
    cmake $NIX_BUILD_TOP/source $cmakeFlags
  '';

  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    make install

    # Create pkg-config file
    mkdir -p $out/lib/pkgconfig
    cat > $out/lib/pkgconfig/protobuf.pc << EOF
    prefix=$out
    exec_prefix=\''${prefix}
    libdir=\''${prefix}/lib
    includedir=\''${prefix}/include

    Name: Protocol Buffers
    Description: Google's Data Interchange Format
    Version: ${version}
    Libs: -L\''${libdir} -lprotobuf
    Cflags: -I\''${includedir}
    EOF
  '';

  doCheck = false;

  meta = with lib; {
    description = "Google's data interchange format";
    homepage = "https://developers.google.com/protocol-buffers/";
    license = licenses.bsd3;
    platforms = platforms.unix;
  };
}
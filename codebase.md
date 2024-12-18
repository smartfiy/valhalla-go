# .github/workflows/build.yml

```yml
name: "Test and build bindings"
on:
  pull_request:
  push:
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: cachix/install-nix-action@v18
      with:
        install_url: https://releases.nixos.org/nix/nix-2.13.3/install
        nix_path: nixpkgs=channel:nixos-unstable
    - uses: cachix/cachix-action@v12
      with:
        name: valhalla-go
        authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
    - run: nix-build
    - uses: actions/upload-artifact@v3
      with:
        name: libvalhalla-go
        path: result/lib/libvalhalla_go.so
    - uses: actions/setup-go@v3
      with:
        go-version: '>=1.17.0'
    - name: Run go test unit
      run: |
        export LD_LIBRARY_PATH=result/lib/
        go test -v

```

# .gitignore

```
result/
main

```

# .idea/.gitignore

```
# Default ignored files
/shelf/
/workspace.xml
# Editor-based HTTP Client requests
/httpRequests/
# Datasource local storage ignored files
/dataSources/
/dataSources.local.xml

```

# .idea/misc.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="SwUserDefinedSpecifications">
    <option name="specTypeByUrl">
      <map />
    </option>
  </component>
</project>
```

# .idea/modules.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectModuleManager">
    <modules>
      <module fileurl="file://$PROJECT_DIR$/.idea/valhalla-go.iml" filepath="$PROJECT_DIR$/.idea/valhalla-go.iml" />
    </modules>
  </component>
</project>
```

# .idea/valhalla-go.iml

```iml
<?xml version="1.0" encoding="UTF-8"?>
<module type="WEB_MODULE" version="4">
  <component name="Go" enabled="true" />
  <component name="NewModuleRootManager">
    <content url="file://$MODULE_DIR$" />
    <orderEntry type="inheritedJdk" />
    <orderEntry type="sourceFolder" forTests="false" />
  </component>
</module>
```

# .idea/vcs.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="VcsDirectoryMappings">
    <mapping directory="$PROJECT_DIR$" vcs="Git" />
  </component>
</project>
```

# bindings_gen.go

```go
//go:build ignore
// +build ignore

package main

import (
	"os"
	"strings"
	"text/template"
	"unicode"
)

type Instance struct {
	Functions map[string]string
}

func ConvertName(name string) string {
	convertedName := ""
	for _, word := range strings.Split(name, "_") {
		r := []rune(word)
		convertedName += string(append([]rune{unicode.ToUpper(r[0])}, r[1:]...))
	}
	return convertedName
}

func writeTemplate(instance *Instance, templatePath, outputPath string) {
	tl, err := template.ParseFiles(templatePath)
	if err != nil {
		panic(err)
	}

	out, err := os.OpenFile(outputPath, os.O_WRONLY|os.O_CREATE, 0755)
	if err != nil {
		panic(err)
	}

	if err = tl.Execute(out, *instance); err != nil {
		panic(err)
	}
}

func main() {
	fn := []string{"route", "locate", "optimized_route", "matrix", "isochrone", "trace_route", "trace_attributes", "height", "transit_available", "expansion", "centroid", "status"}
	instance := Instance{
		Functions: map[string]string{},
	}
	for _, v := range fn {
		instance.Functions[v] = ConvertName(v)
	}

	writeTemplate(&instance, "templates/valhalla_go.templ.cpp", "bindings/valhalla_go.cpp")
	writeTemplate(&instance, "templates/valhalla_go.templ.h", "bindings/valhalla_go.h")
	writeTemplate(&instance, "templates/valhalla.templ.go", "valhalla.go")
}

```

# bindings/default.nix

```nix
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
```

# bindings/protobuf/default.nix

```nix
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
```

# bindings/protobuf/static-executables-have-no-rpath.patch

```patch
diff --git a/cmake/install.cmake b/cmake/install.cmake
index 26a55be8b..b6823c3f9 100644
--- a/cmake/install.cmake
+++ b/cmake/install.cmake
@@ -32,13 +32,6 @@ if (protobuf_BUILD_PROTOC_BINARIES)
   install(TARGETS protoc EXPORT protobuf-targets
     RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT protoc
     BUNDLE DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT protoc)
-  if (UNIX AND NOT APPLE)
-    set_property(TARGET protoc
-      PROPERTY INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
-  elseif (APPLE)
-    set_property(TARGET protoc
-      PROPERTY INSTALL_RPATH "@loader_path/../lib")
-  endif()
 endif (protobuf_BUILD_PROTOC_BINARIES)
 
 install(FILES ${CMAKE_CURRENT_BINARY_DIR}/protobuf.pc ${CMAKE_CURRENT_BINARY_DIR}/protobuf-lite.pc DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")

```

# bindings/valhalla_go.cpp

```cpp
#include <valhalla/tyr/actor.h>
#include <valhalla/baldr/rapidjson_utils.h>
#include <valhalla/midgard/logging.h>
#include <valhalla/midgard/util.h>

#include <boost/make_shared.hpp>
#include <boost/noncopyable.hpp>
#include <boost/optional.hpp>
#include <boost/property_tree/ptree.hpp>

#include "valhalla_go.h"

const boost::property_tree::ptree configure(boost::property_tree::ptree pt, const std::string& config) {
  try {
    boost::optional<boost::property_tree::ptree&> logging_subtree =
        pt.get_child_optional("mjolnir.logging");
    if (logging_subtree) {
      auto logging_config = valhalla::midgard::ToMap<const boost::property_tree::ptree&,
                                                     std::unordered_map<std::string, std::string>>(
          logging_subtree.get());
      valhalla::midgard::logging::Configure(logging_config);
    }
  } catch (...) { throw std::runtime_error("Failed to load config from: " + config); }

  return pt;
}

char* copy_str(const char * string) {
  char *cstr = (char *) malloc(strlen(string) + 1);
  strcpy(cstr, string);
  return cstr;
}

void* actor_init_from_file(const char* config, char * is_error) {
  try {
    boost::property_tree::ptree pt;
    // parse the config and configure logging
    rapidjson::read_json(config, pt);
    auto actor = new valhalla::tyr::actor_t(configure(pt, config), true);
    *is_error = 0;
    return (void*) actor;
  } catch (std::exception& ex) {
    *is_error = 1;
    return (void*) copy_str(ex.what());
  }
}

void* actor_init_from_config(const char* config, char * is_error) {
  try {
    boost::property_tree::ptree pt;
    std::istringstream is(config);
    // parse the config and configure logging
    rapidjson::read_json(is, pt);
    auto actor = new valhalla::tyr::actor_t(configure(pt, config), true);
    *is_error = 0;
    return (void*) actor;
  } catch (std::exception& ex) {
    *is_error = 1;
    return (void*) copy_str(ex.what());
  }
}


const char * actor_centroid(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->centroid(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_expansion(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->expansion(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_height(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->height(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_isochrone(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->isochrone(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_locate(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->locate(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_matrix(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->matrix(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_optimized_route(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->optimized_route(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_route(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->route(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_status(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->status(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_trace_attributes(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->trace_attributes(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_trace_route(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->trace_route(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

const char * actor_transit_available(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->transit_available(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}

```

# bindings/valhalla_go.h

```h
#ifdef __cplusplus
extern "C" {
#endif

typedef void* Actor;
Actor actor_init_from_file(const char*, char *);
Actor actor_init_from_config(const char*, char *);

const char * actor_centroid(Actor, const char *, char *);

const char * actor_expansion(Actor, const char *, char *);

const char * actor_height(Actor, const char *, char *);

const char * actor_isochrone(Actor, const char *, char *);

const char * actor_locate(Actor, const char *, char *);

const char * actor_matrix(Actor, const char *, char *);

const char * actor_optimized_route(Actor, const char *, char *);

const char * actor_route(Actor, const char *, char *);

const char * actor_status(Actor, const char *, char *);

const char * actor_trace_attributes(Actor, const char *, char *);

const char * actor_trace_route(Actor, const char *, char *);

const char * actor_transit_available(Actor, const char *, char *);


#ifdef __cplusplus
}
#endif

```

# bindings/valhalla/default.nix

```nix
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
```

# build_config.go

```go
package valhalla

import "encoding/json"

type Config struct {
	Json map[string]interface{}
}

func DefaultConfig() *Config {
	var config map[string]interface{}
	err := json.Unmarshal([]byte(defaultConfigString), &config)
	if err != nil {
		panic(err)
	}
	return &Config{Json: config}
}

func (config *Config) String() string {
	marshal, err := json.Marshal(config.Json)
	if err != nil {
		return err.Error()
	}
	return string(marshal)
}

func (config *Config) SetTileDirPath(path string) {
	mjolnir := config.Json["mjolnir"].(map[string]interface{})
	mjolnir["tile_dir"] = path
}

func (config *Config) SetTileExtractPath(path string) {
	mjolnir := config.Json["mjolnir"].(map[string]interface{})
	mjolnir["tile_extract"] = path
}

func (config *Config) SetLoggingVerbosity(verbose bool) {
	mjolnir := config.Json["mjolnir"].(map[string]interface{})
	logging := mjolnir["logging"].(map[string]interface{})
	logging["type"] = verbose
}

```

# default_config.go

```go
package valhalla

const defaultConfigString string = `
{
  "additional_data": {
    "elevation": "/data/valhalla/elevation/"
  },
  "httpd": {
    "service": {
      "drain_seconds": 28,
      "interrupt": "ipc:///tmp/interrupt",
      "listen": "tcp://*:8002",
      "loopback": "ipc:///tmp/loopback",
      "shutdown_seconds": 1
    }
  },
  "loki": {
    "actions": [
      "locate",
      "route",
      "height",
      "sources_to_targets",
      "optimized_route",
      "isochrone",
      "trace_route",
      "trace_attributes",
      "transit_available",
      "expansion",
      "centroid",
      "status"
    ],
    "logging": {
      "color": true,
      "file_name": "path_to_some_file.log",
      "long_request": 100.0,
      "type": "std_out"
    },
    "service": {
      "proxy": "ipc:///tmp/loki"
    },
    "service_defaults": {
      "heading_tolerance": 60,
      "minimum_reachability": 50,
      "node_snap_tolerance": 5,
      "radius": 0,
      "search_cutoff": 35000,
      "street_side_max_distance": 1000,
      "street_side_tolerance": 5
    },
    "use_connectivity": true
  },
  "meili": {
    "auto": {
      "search_radius": 50,
      "turn_penalty_factor": 200
    },
    "bicycle": {
      "turn_penalty_factor": 140
    },
    "customizable": [
      "mode",
      "search_radius",
      "turn_penalty_factor",
      "gps_accuracy",
      "interpolation_distance",
      "sigma_z",
      "beta",
      "max_route_distance_factor",
      "max_route_time_factor"
    ],
    "default": {
      "beta": 3,
      "breakage_distance": 2000,
      "geometry": false,
      "gps_accuracy": 5.0,
      "interpolation_distance": 10,
      "max_route_distance_factor": 5,
      "max_route_time_factor": 5,
      "max_search_radius": 100,
      "route": true,
      "search_radius": 50,
      "sigma_z": 4.07,
      "turn_penalty_factor": 0
    },
    "grid": {
      "cache_size": 100240,
      "size": 500
    },
    "logging": {
      "color": true,
      "file_name": "path_to_some_file.log",
      "type": "std_out"
    },
    "mode": "auto",
    "multimodal": {
      "turn_penalty_factor": 70
    },
    "pedestrian": {
      "search_radius": 50,
      "turn_penalty_factor": 100
    },
    "service": {
      "proxy": "ipc:///tmp/meili"
    },
    "verbose": false
  },
  "mjolnir": {
    "admin": "/data/valhalla/admin.sqlite",
    "data_processing": {
      "allow_alt_name": false,
      "apply_country_overrides": true,
      "infer_internal_intersections": true,
      "infer_turn_channels": true,
      "scan_tar": false,
      "use_admin_db": true,
      "use_direction_on_ways": false,
      "use_rest_area": false,
      "use_urban_tag": false
    },
    "global_synchronized_cache": false,
    "hierarchy": true,
    "id_table_size": 1300000000,
    "import_bike_share_stations": false,
    "include_bicycle": true,
    "include_construction": false,
    "include_driveways": true,
    "include_driving": true,
    "include_pedestrian": true,
    "logging": {
      "color": true,
      "file_name": "path_to_some_file.log",
      "type": "std_out"
    },
    "lru_mem_cache_hard_control": false,
    "max_cache_size": 1000000000,
    "max_concurrent_reader_users": 1,
    "reclassify_links": true,
    "shortcuts": true,
    "tile_dir": "/data/valhalla",
    "tile_extract": "/data/valhalla/tiles.tar",
    "timezone": "/data/valhalla/tz_world.sqlite",
    "traffic_extract": "/data/valhalla/traffic.tar",
    "transit_dir": "/data/valhalla/transit",
    "transit_feeds_dir": "/data/valhalla/transit_feeds",
    "use_lru_mem_cache": false,
    "use_simple_mem_cache": false
  },
  "odin": {
    "logging": {
      "color": true,
      "file_name": "path_to_some_file.log",
      "type": "std_out"
    },
    "markup_formatter": {
      "markup_enabled": false,
      "phoneme_format": "<TEXTUAL_STRING> (<span class=<QUOTES>phoneme<QUOTES>>/<VERBAL_STRING>/</span>)"
    },
    "service": {
      "proxy": "ipc:///tmp/odin"
    }
  },
  "service_limits": {
    "auto": {
      "max_distance": 5000000.0,
      "max_locations": 20,
      "max_matrix_distance": 400000.0,
      "max_matrix_location_pairs": 2500
    },
    "bicycle": {
      "max_distance": 500000.0,
      "max_locations": 50,
      "max_matrix_distance": 200000.0,
      "max_matrix_location_pairs": 2500
    },
    "bikeshare": {
      "max_distance": 500000.0,
      "max_locations": 50,
      "max_matrix_distance": 200000.0,
      "max_matrix_location_pairs": 2500
    },
    "bus": {
      "max_distance": 5000000.0,
      "max_locations": 50,
      "max_matrix_distance": 400000.0,
      "max_matrix_location_pairs": 2500
    },
    "centroid": {
      "max_distance": 200000.0,
      "max_locations": 5
    },
    "isochrone": {
      "max_contours": 4,
      "max_distance": 25000.0,
      "max_distance_contour": 200,
      "max_locations": 1,
      "max_time_contour": 120
    },
    "max_alternates": 2,
    "max_exclude_locations": 50,
    "max_exclude_polygons_length": 10000,
    "max_radius": 200,
    "max_reachability": 100,
    "max_timedep_distance": 500000,
    "max_timedep_distance_matrix": 0,
    "motor_scooter": {
      "max_distance": 500000.0,
      "max_locations": 50,
      "max_matrix_distance": 200000.0,
      "max_matrix_location_pairs": 2500
    },
    "motorcycle": {
      "max_distance": 500000.0,
      "max_locations": 50,
      "max_matrix_distance": 200000.0,
      "max_matrix_location_pairs": 2500
    },
    "multimodal": {
      "max_distance": 500000.0,
      "max_locations": 50,
      "max_matrix_distance": 0.0,
      "max_matrix_location_pairs": 0
    },
    "pedestrian": {
      "max_distance": 250000.0,
      "max_locations": 50,
      "max_matrix_distance": 200000.0,
      "max_matrix_location_pairs": 2500,
      "max_transit_walking_distance": 10000,
      "min_transit_walking_distance": 1
    },
    "skadi": {
      "max_shape": 750000,
      "min_resample": 10.0
    },
    "status": {
      "allow_verbose": false
    },
    "taxi": {
      "max_distance": 5000000.0,
      "max_locations": 20,
      "max_matrix_distance": 400000.0,
      "max_matrix_location_pairs": 2500
    },
    "trace": {
      "max_alternates": 3,
      "max_alternates_shape": 100,
      "max_distance": 200000.0,
      "max_gps_accuracy": 100.0,
      "max_search_radius": 100.0,
      "max_shape": 16000
    },
    "transit": {
      "max_distance": 500000.0,
      "max_locations": 50,
      "max_matrix_distance": 200000.0,
      "max_matrix_location_pairs": 2500
    },
    "truck": {
      "max_distance": 5000000.0,
      "max_locations": 20,
      "max_matrix_distance": 400000.0,
      "max_matrix_location_pairs": 2500
    }
  },
  "statsd": {
    "port": 8125,
    "prefix": "valhalla"
  },
  "thor": {
    "clear_reserved_memory": false,
    "extended_search": false,
    "logging": {
      "color": true,
      "file_name": "path_to_some_file.log",
      "long_request": 110.0,
      "type": "std_out"
    },
    "max_reserved_labels_count": 1000000,
    "service": {
      "proxy": "ipc:///tmp/thor"
    },
    "source_to_target_algorithm": "select_optimal"
  }
}
`

```

# default.nix

```nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./bindings {}

```

# go.mod

```mod
module github.com/vandreltd/valhalla-go

go 1.18

```

# LICENSE

```
Copyright (c) 2023 Vandre Ltd. <vandreltd@gmail.com>

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

```

# oryxBuildBinary

This is a binary file of the type: Binary

# README.md

```md
# Valhalla for Go

[![Test and build bindings](https://github.com/vandreltd/valhalla-go/actions/workflows/build.yml/badge.svg)](https://github.com/vandreltd/valhalla-go/actions/workflows/build.yml)

This repo simply offers Go bindings to the [Valhalla project](https://github.com/valhalla/valhalla).

## Usage

The library offer functions that directly take JSON string request and return JSON string response.
Example code on how to use the library can be found in the [test units](/valhalla_test.go).

Note that the library depends on C++ bindings. If you have the [Nix package manager](https://nixos.org/) you can simply build the bindings as such:
\`\`\`
git clone https://github.com/vandreltd/valhalla-go
cd valhalla-go
nix-build # the shared library will be in result/lib/
LD_LIBRARY_PATH=./result/lib go test -v # build and run the test units
\`\`\`

If you do not wish the build the library yourself, you can grab a pre-built binary in the [CI Artifacts](https://github.com/vandreltd/valhalla-go/actions).

A preprocessed tiles file of the entire world (2023 Jan) can be found [here](https://archive.org/download/valhalla-planet-221219).

## License

`valhalla-go` is licensed with ISC, see [LICENSE](./LICENSE).

```

# templates/valhalla_go.templ.cpp

```cpp
#include <valhalla/tyr/actor.h>
#include <valhalla/baldr/rapidjson_utils.h>
#include <valhalla/midgard/logging.h>
#include <valhalla/midgard/util.h>

#include <boost/make_shared.hpp>
#include <boost/noncopyable.hpp>
#include <boost/optional.hpp>
#include <boost/property_tree/ptree.hpp>

#include "valhalla_go.h"

const boost::property_tree::ptree configure(boost::property_tree::ptree pt, const std::string& config) {
  try {
    boost::optional<boost::property_tree::ptree&> logging_subtree =
        pt.get_child_optional("mjolnir.logging");
    if (logging_subtree) {
      auto logging_config = valhalla::midgard::ToMap<const boost::property_tree::ptree&,
                                                     std::unordered_map<std::string, std::string>>(
          logging_subtree.get());
      valhalla::midgard::logging::Configure(logging_config);
    }
  } catch (...) { throw std::runtime_error("Failed to load config from: " + config); }

  return pt;
}

char* copy_str(const char * string) {
  char *cstr = (char *) malloc(strlen(string) + 1);
  strcpy(cstr, string);
  return cstr;
}

void* actor_init_from_file(const char* config, char * is_error) {
  try {
    boost::property_tree::ptree pt;
    // parse the config and configure logging
    rapidjson::read_json(config, pt);
    auto actor = new valhalla::tyr::actor_t(configure(pt, config), true);
    *is_error = 0;
    return (void*) actor;
  } catch (std::exception& ex) {
    *is_error = 1;
    return (void*) copy_str(ex.what());
  }
}

void* actor_init_from_config(const char* config, char * is_error) {
  try {
    boost::property_tree::ptree pt;
    std::istringstream is(config);
    // parse the config and configure logging
    rapidjson::read_json(is, pt);
    auto actor = new valhalla::tyr::actor_t(configure(pt, config), true);
    *is_error = 0;
    return (void*) actor;
  } catch (std::exception& ex) {
    *is_error = 1;
    return (void*) copy_str(ex.what());
  }
}

{{ range $k, $v := .Functions }}
const char * actor_{{$k}}(Actor actor, const char * req, char * is_error) {
  try {
    std::string resp = ((valhalla::tyr::actor_t*) actor)->{{$k}}(req);
    *is_error = 0;
    return copy_str(resp.c_str());
  } catch (std::exception& ex) {
    *is_error = 1;
    return copy_str(ex.what());
  }
}
{{ end }}
```

# templates/valhalla_go.templ.h

```h
#ifdef __cplusplus
extern "C" {
#endif

typedef void* Actor;
Actor actor_init_from_file(const char*, char *);
Actor actor_init_from_config(const char*, char *);
{{ range $k, $v := .Functions }}
const char * actor_{{$k}}(Actor, const char *, char *);
{{ end }}

#ifdef __cplusplus
}
#endif

```

# templates/valhalla.templ.go

```go
package valhalla

// #cgo LDFLAGS: -L./result/lib -lvalhalla_go
// #include <stdio.h>
// #include <stdlib.h>
// #include "./bindings/valhalla_go.h"
import "C"
import (
	"errors"
	"unsafe"
)

type Actor struct {
	ptr unsafe.Pointer
}

func NewActorFromFile(configPath string) (*Actor, error) {
	var isError uint8 = 0
	cs := C.CString(configPath)
	resp := C.actor_init_from_file(cs, (*C.char)(unsafe.Pointer(&isError)))
	C.free(unsafe.Pointer(cs))
	switch isError {
	case 0:
		return &Actor{ptr: unsafe.Pointer(resp)}, nil
	case 1:
		err := C.GoString((*C.char)(resp))
		C.free(unsafe.Pointer(resp))
		return nil, errors.New(err)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func NewActorFromConfig(config *Config) (*Actor, error) {
	var isError uint8 = 0
	cs := C.CString(config.String())
	resp := C.actor_init_from_config(cs, (*C.char)(unsafe.Pointer(&isError)))
	C.free(unsafe.Pointer(cs))
	switch isError {
	case 0:
		return &Actor{ptr: unsafe.Pointer(resp)}, nil
	case 1:
		err := C.GoString((*C.char)(resp))
		C.free(unsafe.Pointer(resp))
		return nil, errors.New(err)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

{{ range $k, $v := .Functions }}
func (actor *Actor) {{$v}}(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_{{$k}}((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}
{{ end }}
```

# test/data/utrecht_tiles/0/003/196.gph

This is a binary file of the type: Binary

# test/data/utrecht_tiles/1/051/305.gph

This is a binary file of the type: Binary

# test/data/utrecht_tiles/2/000/818/660.gph

This is a binary file of the type: Binary

# test/data/utrecht_tiles/tiles.tar

This is a binary file of the type: Binary

# valhalla_test.go

```go
package valhalla

import (
	"encoding/json"
	"regexp"
	"strings"
	"testing"
)

const (
	tilesPath   = "./test/data/utrecht_tiles"
	extractPath = "./test/data/utrecht_tiles/tiles.tar"
)

func testActor(t *testing.T) *Actor {
	config := DefaultConfig()
	config.SetTileDirPath(tilesPath)
	config.SetTileExtractPath(extractPath)
	actor, err := NewActorFromConfig(config)
	if err != nil {
		t.Fatal(err.Error())
		return nil
	}
	return actor
}

func TestConfig(t *testing.T) {
	config := DefaultConfig()
	config.SetTileDirPath(tilesPath)
	config.SetTileExtractPath(extractPath)

	mjolnir := config.Json["mjolnir"].(map[string]interface{})
	if mjolnir["tile_extract"] != extractPath {
		t.Fatal("tile_extract does not match")
	}
	if mjolnir["tile_dir"] != tilesPath {
		t.Fatal("tile_dir does not match")
	}
}

func TestConfigNoTiles(t *testing.T) {
	_, err := NewActorFromFile("non_existent_path")
	if err == nil {
		t.Fatal("File not found error expected")
	} else {
		t.Logf("Expected error: %s\n", err.Error())
	}
}

func TestConfigActor(t *testing.T) {
	actor := testActor(t)
	response, err := actor.Status("")
	if err != nil {
		t.Fatal(err.Error())
	}
	var status map[string]interface{}
	err = json.Unmarshal([]byte(response), &status)
	if err != nil {
		t.Fatal(err.Error())
	}
	if status["tileset_last_modified"] == nil {
		t.Fatal("tileset_last_modified expected in status response")
	}
}

func TestRoute(t *testing.T) {
	query := `{
      "locations": [{"lat": 52.08813, "lon": 5.03231}, {"lat": 52.09987, "lon": 5.14913}],
      "costing": "bicycle",
      "directions_options": {"language": "ru-RU"}
    }`
	actor := testActor(t)
	response, err := actor.Route(query)
	if err != nil {
		t.Fatal(err.Error())
	}

	var route map[string]interface{}
	err = json.Unmarshal([]byte(response), &route)
	if err != nil {
		t.Fatal(err.Error())
	}

	trip := route["trip"].(map[string]interface{})
	if trip == nil {
		t.Fatal("trip expected in route response")
	}

	units := trip["units"]
	if units == nil {
		t.Fatal("units expected in route response")
	}

	if units.(string) != "kilometers" {
		t.Fatal("units is expected to be kilometers in route response")
	}

	summary := trip["summary"].(map[string]interface{})
	if summary == nil {
		t.Fatal("summary expected in route response")
	}

	length := summary["length"]
	if length == nil {
		t.Fatal("length expected in route response")
	}
	if length.(float64) <= 0.7 {
		t.Fatal("length expected to be greater than 0.7 in route response")
	}

	legs := trip["legs"]
	if legs == nil {
		t.Fatal("legs expected in route response")
	}
	if len(legs.([]interface{})) <= 0 {
		t.Fatal("legs expected to be greater than 0 in route response")
	}

	maneuvers := legs.([]interface{})[0].(map[string]interface{})["maneuvers"]
	if maneuvers == nil {
		t.Fatal("maneuvers expected in route response")
	}
	if len(maneuvers.([]interface{})) <= 0 {
		t.Fatal("maneuvers expected to be greater than 0 in route response")
	}

	instruction := maneuvers.([]interface{})[0].(map[string]interface{})["instruction"]
	if instruction == nil {
		t.Fatal("maneuvers expected in route response")
	}
	match, err := regexp.Match("[\u0400-\u04FF]", []byte(instruction.(string)))
	if err != nil {
		t.Fatal(err.Error())
	}
	if !match {
		t.Fatal("Cyrillic not found in instruction")
	}
}
func TestIsochrone(t *testing.T) {
	query := `{
        "locations": [{"lat": 52.08813, "lon": 5.03231}],
        "costing": "pedestrian",
        "contours": [{"time": 1}, {"time": 5}, {"distance": 1}, {"distance": 5}],
        "show_locations": true
    }`
	actor := testActor(t)
	response, err := actor.Isochrone(query)
	if err != nil {
		t.Fatal(err.Error())
	}

	var isochrone map[string]interface{}
	err = json.Unmarshal([]byte(response), &isochrone)
	if err != nil {
		t.Fatal(err.Error())
	}

	if len((isochrone["features"]).([]interface{})) != 6 {
		t.Fatal("Expected 4 isochrones and 2 point layers in response")
	}
}

func TestChangeConfig(t *testing.T) {
	query := `{
      "locations": [
          {"lat": 52.08813, "lon": 5.03231},
          {"lat": 52.09987, "lon": 5.14913}
      ],
      "costing": "bicycle",
      "directions_options": {"language": "ru-RU"}
    }`
	config := DefaultConfig()
	config.SetTileDirPath(tilesPath)
	config.SetTileExtractPath(extractPath)
	config.Json["service_limits"].(map[string]interface{})["bicycle"].(map[string]interface{})["max_distance"] = 1
	actor, err := NewActorFromConfig(config)
	if err != nil {
		t.Fatal(err.Error())
	}

	_, err = actor.Route(query)
	if err == nil {
		t.Fatal("Error expected but not found")
	}
	if !strings.Contains(err.Error(), "exceeds the max distance limit") {
		t.Fatal(err.Error())
	}
}

```

# valhalla.go

```go
package valhalla

// #cgo LDFLAGS: -L./result/lib -lvalhalla_go
// #include <stdio.h>
// #include <stdlib.h>
// #include "./bindings/valhalla_go.h"
import "C"
import (
	"errors"
	"unsafe"
)

type Actor struct {
	ptr unsafe.Pointer
}

func NewActorFromFile(configPath string) (*Actor, error) {
	var isError uint8 = 0
	cs := C.CString(configPath)
	resp := C.actor_init_from_file(cs, (*C.char)(unsafe.Pointer(&isError)))
	C.free(unsafe.Pointer(cs))
	switch isError {
	case 0:
		return &Actor{ptr: unsafe.Pointer(resp)}, nil
	case 1:
		err := C.GoString((*C.char)(resp))
		C.free(unsafe.Pointer(resp))
		return nil, errors.New(err)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func NewActorFromConfig(config *Config) (*Actor, error) {
	var isError uint8 = 0
	cs := C.CString(config.String())
	resp := C.actor_init_from_config(cs, (*C.char)(unsafe.Pointer(&isError)))
	C.free(unsafe.Pointer(cs))
	switch isError {
	case 0:
		return &Actor{ptr: unsafe.Pointer(resp)}, nil
	case 1:
		err := C.GoString((*C.char)(resp))
		C.free(unsafe.Pointer(resp))
		return nil, errors.New(err)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}


func (actor *Actor) Centroid(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_centroid((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) Expansion(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_expansion((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) Height(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_height((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) Isochrone(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_isochrone((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) Locate(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_locate((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) Matrix(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_matrix((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) OptimizedRoute(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_optimized_route((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) Route(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_route((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) Status(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_status((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) TraceAttributes(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_trace_attributes((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) TraceRoute(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_trace_route((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}

func (actor *Actor) TransitAvailable(request string) (string, error) {
	var isError uint8 = 0
	cs := C.CString(request)
	cresp := C.actor_transit_available((C.Actor)(actor.ptr), cs, (*C.char)(unsafe.Pointer(&isError)))
	resp := C.GoString(cresp)
	C.free(unsafe.Pointer(cresp))
	switch isError {
	case 0:
		return resp, nil
	case 1:
		return "", errors.New(resp)
	default:
		panic("Invalid error code from valhalla C binding")
	}
}


```


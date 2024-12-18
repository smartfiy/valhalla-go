cmake_minimum_required(VERSION 3.10)
project(valhalla-go)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Create the shared library
add_library(valhalla_go SHARED
    bindings/valhalla_go.cpp
)

# Find required packages
find_package(Boost REQUIRED)
find_package(Protobuf CONFIG REQUIRED)
find_package(ZLIB REQUIRED)

# Include directories
target_include_directories(valhalla_go PRIVATE
    ${Boost_INCLUDE_DIRS}
    ${Protobuf_INCLUDE_DIRS}
    ${CMAKE_SOURCE_DIR}/bindings
    ${CMAKE_BINARY_DIR}
)

# Link libraries
target_link_libraries(valhalla_go PRIVATE
    valhalla
    protobuf::libprotobuf
    ${Boost_LIBRARIES}
    ${ZLIB_LIBRARIES}
    pthread
)

# Installation rules
install(TARGETS valhalla_go
    LIBRARY DESTINATION lib
)
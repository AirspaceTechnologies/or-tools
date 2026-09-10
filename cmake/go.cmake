if(NOT BUILD_GO)
  return()
endif()

if(NOT TARGET ${PROJECT_NAMESPACE}::ortools)
  message(FATAL_ERROR "Go: missing ortools TARGET")
endif()

# Will need swig
set(CMAKE_SWIG_FLAGS)
find_package(SWIG REQUIRED)
include(UseSWIG)

#if(${SWIG_VERSION} VERSION_GREATER_EQUAL 4)
#  list(APPEND CMAKE_SWIG_FLAGS "-doxygen")
#endif()

if(UNIX AND NOT APPLE)
  list(APPEND CMAKE_SWIG_FLAGS "-DSWIGWORDSIZE64")
endif()
list(APPEND CMAKE_SWIG_FLAGS "-DOR_DLL=")

# Set SWIG flags for Go
list(APPEND CMAKE_SWIG_FLAGS "-c++" "-cgo" "-intgosize" "64")

# Find go cli
# -race requires a 48-bit VMA on arm64; QEMU user emulation only provides 47,
# so cross-arch delivery builds disable it (tests still run un-instrumented)
option(GO_TEST_RACE "Run Go example tests with -race" ON)

find_program(GO_EXECUTABLE NAMES go)
if(NOT GO_EXECUTABLE)
  message(FATAL_ERROR "Check for go Program: not found")
  message(STATUS "Found go Program: ${GO_EXECUTABLE}")
endif()

# Needed by go/CMakeLists.txt
set(GO_OR_TOOLS_NATIVE_LIB goortools)
set(PKG_ROOT github.com/airspacetechnologies/or-tools/go/ortools)

if(APPLE)
  set(RUNTIME_IDENTIFIER osx-x64)
elseif(UNIX)
  set(RUNTIME_IDENTIFIER linux-x64)
elseif(WIN32)
  set(RUNTIME_IDENTIFIER win-x64)
else()
  message(FATAL_ERROR "Unsupported system !")
endif()
set(GO_PACKAGE ortools)
set(GO_NATIVE_PROJECT ${GO_PACKAGE}-${RUNTIME_IDENTIFIER})
message(STATUS "Go runtime project: ${GO_NATIVE_PROJECT}")
set(GO_NATIVE_PROJECT_DIR ${PROJECT_BINARY_DIR}/go/${GO_NATIVE_PROJECT})
message(STATUS "Go runtime project build path: ${GO_NATIVE_PROJECT_DIR}")

set(GO_PROJECT ${GO_PACKAGE})
message(STATUS "Go project: ${GO_PROJECT}")
set(GO_DIR ${PROJECT_BINARY_DIR}/go)
set(GO_PROJECT_DIR ${GO_DIR}/${GO_PROJECT})
message(STATUS "Go project build path: ${GO_PROJECT_DIR}")

# Create the native library
add_library(goortools SHARED "")
set_target_properties(goortools PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
# note: macOS is APPLE and also UNIX !
if(APPLE)
  target_link_options(goortools PRIVATE -undefined dynamic_lookup)

  # Use absolute install path to work around bug with MacOS 14/XCode 15:
  # https://developer.apple.com/forums/thread/737920?answerId=766944022#766944022
  set_target_properties(goortools PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE)
  set_target_properties(goortools PROPERTIES BUILD_WITH_INSTALL_NAME_DIR TRUE)
  set_target_properties(goortools PROPERTIES SKIP_BUILD_RPATH TRUE)
  set_target_properties(goortools PROPERTIES INSTALL_NAME_DIR "/usr/local/lib")
  set_target_properties(goortools PROPERTIES INSTALL_RPATH "/usr/local/lib")
  # set_target_properties(goortools PROPERTIES INSTALL_RPATH "@loader_path")

  # Xcode fails to build if library doesn't contains at least one source file.
  if(XCODE)
    file(GENERATE
      OUTPUT ${PROJECT_BINARY_DIR}/goortools/version.cpp
      CONTENT "namespace {char* version = \"${PROJECT_VERSION}\";}")
    target_sources(goortools PRIVATE ${PROJECT_BINARY_DIR}/goortools/version.cpp)
  endif()
elseif(UNIX)
  set_target_properties(goortools PROPERTIES INSTALL_RPATH "$ORIGIN")
endif()

###################
##  GO WRAPPERS  ##
###################
list(APPEND CMAKE_SWIG_FLAGS "-I${PROJECT_SOURCE_DIR}")

# Swig wrap all libraries
set(WRAPPED_GOS)
foreach(SUBPROJECT IN ITEMS constraint_solver)
  add_subdirectory(ortools/${SUBPROJECT}/go)
  target_link_libraries(goortools PRIVATE go_${SUBPROJECT})

  # Custom targets to migrate generated Go files to proper project directory
  string(REGEX REPLACE "_" "" SUBPROJECT_STRIPPED ${SUBPROJECT})
  message(STATUS "Generating wrapped go target for: ${SUBPROJECT_STRIPPED}")
  add_custom_command(
    OUTPUT ${GO_PROJECT_DIR}/${SUBPROJECT_STRIPPED}/wrapped.timestamp
    COMMAND ${CMAKE_COMMAND} -E make_directory ${GO_PROJECT_DIR}/${SUBPROJECT_STRIPPED}
    COMMAND ${CMAKE_COMMAND} -E copy
      ${PROJECT_BINARY_DIR}/${GO_PROJECT}/${SUBPROJECT}/go/wrap/*.go
      ${GO_PROJECT_DIR}/${SUBPROJECT_STRIPPED}/
    COMMAND ${CMAKE_COMMAND} -E touch ${GO_PROJECT_DIR}/${SUBPROJECT_STRIPPED}/wrapped.timestamp
    DEPENDS goortools)
  list(APPEND WRAPPED_GOS ${GO_PROJECT_DIR}/${SUBPROJECT_STRIPPED}/wrapped.timestamp)
endforeach()
add_custom_target(go${PROJECT_NAME}_wrapped DEPENDS ${WRAPPED_GOS} ${PROJECT_NAMESPACE}::ortools)


# Generate Protobuf Go sources
set(PROTO_GOS)
file(GLOB_RECURSE proto_go_files RELATIVE ${PROJECT_SOURCE_DIR}
  "ortools/constraint_solver/search_limit.proto"
  "ortools/constraint_solver/solver_parameters.proto"
  "ortools/constraint_solver/routing_parameters.proto"
  "ortools/constraint_solver/routing_enums.proto"
  "ortools/constraint_solver/routing_heuristic_parameters.proto"
  "ortools/constraint_solver/routing_ils.proto"
  "ortools/sat/sat_parameters.proto"
  "ortools/util/optional_boolean.proto"
  )
foreach(PROTO_FILE IN LISTS proto_go_files)
  #message(STATUS "protoc proto(go): ${PROTO_FILE}")
  get_filename_component(PROTO_DIR ${PROTO_FILE} DIRECTORY)
  get_filename_component(PROTO_NAME ${PROTO_FILE} NAME_WE)
  set(PROTO_ORIG_GO ${GO_DIR}/${PROTO_DIR}/${PROTO_NAME}.pb.go)
  string(REGEX REPLACE "_" "" PROTO_DIR ${PROTO_DIR})
  set(PROTO_GO ${GO_DIR}/${PROTO_DIR}/${PROTO_NAME}.pb.go)
  #message(STATUS "protoc go: ${PROTO_GO}")
  add_custom_command(
    OUTPUT ${PROTO_GO}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_BINARY_DIR}/go/${PROTO_DIR}
    COMMAND ${PROTOC_PRG}
      "--proto_path=${PROJECT_SOURCE_DIR}"
      ${PROTO_DIRS}
      "--go_out=${GO_DIR}"
      "--go_opt=paths=source_relative"
      ${PROTO_FILE}
    COMMAND ${CMAKE_COMMAND} -E copy
      ${PROTO_ORIG_GO}
      ${PROTO_GO}
    DEPENDS ${PROTO_FILE} ${PROTOC_PRG}
    COMMENT "Generate Go protocol buffer for ${PROTO_FILE}"
    VERBATIM)
  list(APPEND PROTO_GOS ${PROTO_GO})
endforeach()
add_custom_target(go${PROJECT_NAME}_proto DEPENDS ${PROTO_GOS} ${PROJECT_NAMESPACE}::ortools)

add_custom_command(
  OUTPUT ${GO_PROJECT_DIR}/clean_constraint_solver
  COMMAND ${CMAKE_COMMAND} -E rm -rf ${GO_PROJECT_DIR}/constraint_solver
  DEPENDS go${PROJECT_NAME}_proto
  COMMENT "Cleaning Go protocol buffer directory constraint_solver"
  VERBATIM)
set_source_files_properties(${GO_PROJECT_DIR}/clean_constraint_solver PROPERTIES SYMBOLIC "true")

####################
##  Go Package  ##
####################
add_custom_command(
  OUTPUT ${GO_PROJECT_DIR}/timestamp
  COMMAND ${GO_EXECUTABLE} mod init ${PKG_ROOT} || true
  COMMAND ${GO_EXECUTABLE} mod tidy
  COMMAND ${GO_EXECUTABLE} build ./...
  COMMAND ${CMAKE_COMMAND} -E touch ${GO_PROJECT_DIR}/timestamp
  DEPENDS
    goortools
    go${PROJECT_NAME}_proto
    go${PROJECT_NAME}_wrapped
    ${GO_PROJECT_DIR}/clean_constraint_solver
  COMMENT "Generate Go package ${GO_PROJECT} (${GO_PROJECT_DIR}/timestamp)"
  WORKING_DIRECTORY ${GO_PROJECT_DIR})

add_custom_target(go_package ALL
  DEPENDS
    ${GO_PROJECT_DIR}/timestamp
  WORKING_DIRECTORY ${GO_PROJECT_DIR})

####################
##  Go Example  ##
####################
# add_go_example()
# CMake function to generate and build go example.
# Parameters:
#  the go filename
# e.g.:
# add_go_example(Foo.go)
function(add_go_example FILE_NAME)
  message(STATUS "Configuring example ${FILE_NAME} ...")
  get_filename_component(EXAMPLE_NAME ${FILE_NAME} NAME_WE)
  get_filename_component(COMPONENT_DIR ${FILE_NAME} DIRECTORY)
  get_filename_component(COMPONENT_NAME ${COMPONENT_DIR} NAME)

  set(GO_EXAMPLE_DIR ${GO_PROJECT_DIR}/${COMPONENT_NAME})
  message(STATUS "build path: ${GO_EXAMPLE_DIR}")

  add_custom_command(
    OUTPUT ${GO_EXAMPLE_DIR}/${EXAMPLE_NAME}.go
    COMMAND ${CMAKE_COMMAND} -E make_directory ${GO_EXAMPLE_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy ${FILE_NAME} ${GO_EXAMPLE_DIR}/
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${COMPONENT_DIR}/README.md ${GO_EXAMPLE_DIR}/
    MAIN_DEPENDENCY ${FILE_NAME}
    VERBATIM
  )

  # All of a component's examples share one Go package dir and `go test`
  # compiles every *_test.go present, so each test must wait for ALL of the
  # component's sources to be copied; under parallel make, depending only on
  # this example's copy races against the sibling copies
  if(NOT TARGET go_${COMPONENT_NAME}_example_srcs)
    add_custom_target(go_${COMPONENT_NAME}_example_srcs)
  endif()
  add_custom_target(go_copy_${COMPONENT_NAME}_${EXAMPLE_NAME}
    DEPENDS ${GO_EXAMPLE_DIR}/${EXAMPLE_NAME}.go)
  add_dependencies(go_${COMPONENT_NAME}_example_srcs go_copy_${COMPONENT_NAME}_${EXAMPLE_NAME})

  if(APPLE)
    set(CGO_ENVS CGO_LDFLAGS=-L${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    set(LD_ENVS DYLD_LIBRARY_PATH=${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
  elseif(UNIX)
    set(CGO_ENVS CGO_LDFLAGS=-L${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    set(LD_ENVS LD_LIBRARY_PATH=${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
  endif()
  add_custom_command(
    OUTPUT ${GO_EXAMPLE_DIR}/${EXAMPLE_NAME}.run
    COMMAND ${CGO_ENVS} ${GO_EXECUTABLE} test -exec "env ${LD_ENVS}" ./... -run /${EXAMPLE_NAME}/i $<$<BOOL:${GO_TEST_RACE}>:-race> -v
    DEPENDS
      ${GO_EXAMPLE_DIR}/${EXAMPLE_NAME}.go
      go_${COMPONENT_NAME}_example_srcs
      go_package
    COMMENT "Compiling Go ${COMPONENT_NAME}/${EXAMPLE_NAME}.go (${GO_EXAMPLE_DIR}/${EXAMPLE_NAME}.run)"
    WORKING_DIRECTORY ${GO_EXAMPLE_DIR})
  set_source_files_properties(${GO_EXAMPLE_DIR}/${EXAMPLE_NAME}.run PROPERTIES SYMBOLIC "true")

  add_custom_target(go_${COMPONENT_NAME}_${EXAMPLE_NAME} ALL
    DEPENDS
      ${GO_EXAMPLE_DIR}/${EXAMPLE_NAME}.run
    WORKING_DIRECTORY ${GO_EXAMPLE_DIR})

  message(STATUS "Configuring example ${FILE_NAME} done")
endfunction()

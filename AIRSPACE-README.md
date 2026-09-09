# Airspace Golang Wrapper Repo for OR-Tools

This is a fork of [Google's OR-Tools repo](https://github.com/google/or-tools).
It has Go bindings and binaries for use with Go projects.

## Install (Mac)
 1. Download binaries for Mac:
    `https://github.com/AirspaceTechnologies/or-tools/releases/download/v9.15-go1.26.5/or-tools_universal_macOS-26.1_go_v9.15.6826.tar.gz`
 1. Install/extract to `/usr/local/lib`:
    `sudo tar -xf or-tools_universal_macOS-26.1_go_v9.15.6826.tar.gz --strip 1 -C /usr/local/lib`
 1. Clean module download cache if necessary:
    `go clean --modcache`

## Install (Linux)
 1. Download binaries for the host architecture (`x86_64` or `aarch64`), e.g.:
    `https://github.com/AirspaceTechnologies/or-tools/releases/download/v9.15-go1.26.5/or-tools_x86_64_AlmaLinux-8.10_go_v9.15.6826.tar.gz`
 1. Install/extract to `/usr/local/lib`:
    `tar -xf or-tools_x86_64_AlmaLinux-8.10_go_v9.15.6826.tar.gz --strip 1 -C /usr/local/lib && ldconfig`

## Install to a Custom Location (Mac)
 By default, the Mac binary releases embed an absolute install path (`/usr/local/lib`).
 To install the binaries to a different location:
 1. Repeat steps 1 and 2 above, replacing `/usr/local/lib` with custom `/install/path`
 1. Set shared library's embedded install path relative to `@rpath`, and add rpath accordingly:
    `install_name_tool -id @rpath/libgoortools.dylib -add_rpath /install/path /install/path/libgoortools.dylib`
 1. Provide linker search path and runtime search path via CGO env var when compiling or running Go tests:
    `CGO_LDFLAGS='-L/install/path -Wl,-rpath,/install/path'`

## Develop (Mac)

### Setup
<details>
  <summary>Required once; expand for steps</summary>

  1. Install XCode:
     `xcode-select --install`
  1. Install C++ tools:
     `brew install wget pkg-config`
  1. Install CMake matching `CMAKE_VERSION` in `tools/release/toolchain.env`:
     download the installer from https://github.com/Kitware/CMake/releases
     or keep a parallel copy on `PATH` for or-tools builds
  1. Install SWIG matching `SWIG_VERSION` in `tools/release/toolchain.env`:
     `brew install swig`
  1. Install Go matching `GO_VERSION` in `tools/release/toolchain.env`
  1. Install protobuf for Go, matching `PROTOC_GEN_GO_VERSION` in `tools/release/toolchain.env`:
     `$ go install google.golang.org/protobuf/cmd/protoc-gen-go@<version>`
  1. Clone Airspace OR-tools:
     `git clone git@github.com:AirspaceTechnologies/or-tools.git`
</details>

### Build and Release
 Releases are built by the `airspace_release` GitHub Actions workflow:
  1. Dry run (formal pre-release step): Actions -> `airspace_release` ->
     `Run workflow`. Builds and verifies all three tarballs; releases nothing
  1. When green, tag that same commit and push the tag:
     `git tag vX.Y-goZ <sha> && git push origin vX.Y-goZ`

     The tag run promotes the dry-run artifacts into a draft release (same
     commit, within 7 days), and rebuilds from scratch otherwise
  1. Review the draft release, edit notes, publish

 Manual/local steps:
  1. For native host machine (e.g. MacOS x86_64):
     `sh native.sh`
  1. Cross-compile for the other Mac architecture (x86_64 on an arm64 Mac,
     and vice versa):
     `sh cross.sh`
  1. Create universal Mac binaries:
     `sh universal.sh -a [arm64 tar ball] -x [x86_64 tar ball] -o [output tar ball]`

     For example: `sh universal.sh -a export/or-tools_arm64_macOS-26.1_go_v9.15.6826.tar.gz -x export/or-tools_x86_64_macOS-26.1_go_v9.15.6826.tar.gz -o export/or-tools_universal_macOS-26.1_go_v9.15.6826.tar.gz`
  1. For Linux x86_64 (~1 hour natively, uses Docker to build everything from scratch):
     `sh tools/release/build_delivery_airspace.sh go amd64`
  1. For Linux aarch64:
     `sh tools/release/build_delivery_airspace.sh go arm64`
  1. Log into Github and create a release with the resulting binaries in the `export` directory

### Update Fork from Upstream
 1. Configure git remote pointing to upstream or-tools repo:
    `git remote add upstream git@github.com:google/or-tools.git`
 1. Fetch upstream:
    `git fetch upstream`
 1. Checkout fork's `stable` branch and pull:
    `git checkout stable && git pull`
 1. Merge changes from upstream `stable` branch:
    `git merge upstream/stable`
 1. Push fork's `stable` branch:
    `git push`
 1. Create a cycle branch off fork's `airspace` branch:
    `git checkout airspace && git pull && git checkout -b airspace-vX.Y`
 1. Merge changes from `stable` into the cycle branch:
    `git merge stable`
 1. Push the cycle branch and open a PR into `airspace`:
    `git push -u origin airspace-vX.Y`
 1. Build and release using steps above

## TODO
 1. Make `IntVar`->`IntExpr` casting cleaner

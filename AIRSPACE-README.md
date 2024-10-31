# Airspace Golang Wrapper Repo for OR-Tools

This is a fork of [Google's OR-Tools repo](https://github.com/google/or-tools).
It has Go bindings and binaries for use with Go projects.

## Install (Mac)
 1. Download binaries for Mac:
    `https://github.com/AirspaceTechnologies/or-tools/releases/download/v9.10-go1.23.0/or-tools_universal_macOS-14.4.1_go_v9.10.4129.tar.gz`
 1. Install/extract to `/usr/local/lib`:
    `sudo tar -xf or-tools_universal_macOS-14.4.1_go_v9.10.4129.tar.gz --strip 1 -C /usr/local/lib`
 1. Clean module download cache if necessary:
    `go clean --modcache`

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
     `brew install cmake wget pkg-config`
  1. Install SWIG 4.3.0:
     `brew install swig@4.3.0`
  1. Install protobuf for Go:
     `$ go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.33`
  1. Clone Airspace OR-tools:
     `git clone git@github.com:AirspaceTechnologies/or-tools.git`
</details>

### Build and Release
  1. For native host machine (e.g. MacOS x86_64):
     `sh native.sh`
  1. Cross-compile for Mac arm64 (e.g. Mac M1, M2):
     `sh arm.sh`
  1. Create universal Mac binaries:
     `sh universal.sh -a [arm64 tar ball] -x [x86_64 tar ball] -o [output tar ball]`

     For example: `sh universal.sh -a export/or-tools_arm64_macOS-14.4.1_go_v9.10.4129.tar.gz -x export/or-tools_x86_64_macOS-14.4.1_go_v9.10.4129.tar.gz -o export/or-tools_universal_macOS-14.4.1_go_v9.10.4129.tar.gz`
  1. For Linux x86_64 (takes ~45 mins, uses Docker to build everything from scratch):
     `sh tools/release/build_delivery_airspace.sh`
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
 1. Checkout fork's `airspace` branch and pull:
    `git checkout airspace && git pull`
 1. Merge changes from `stable` to `airspace` branch:
    `git merge stable`
 1. Push fork's `airspace` branch:
    `git push`
 1. Optionally build and release using steps above

## TODO
 1. Make `IntVar`->`IntExpr` casting cleaner

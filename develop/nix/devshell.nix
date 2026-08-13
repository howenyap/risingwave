{ inputs
, ...
}:

{
  perSystem = { pkgs, lib, ... }: {
    devshells.default =
      let
        rust-toolchain = with pkgs;
          [
            ((rust-bin.fromRustupToolchainFile ../../rust-toolchain).override {
              extensions = [ "rust-src" "rust-analyzer" ];
            })
          ];
        darwin-cmake-toolchain = pkgs.writeText "risingwave-darwin-toolchain.cmake" ''
          if(DEFINED ENV{NIX_CXX})
            set(CMAKE_CXX_COMPILER "$ENV{NIX_CXX}" CACHE FILEPATH "" FORCE)
          endif()
          set(OpenMP_CXX_FLAGS "-Xpreprocessor -fopenmp -I${pkgs.llvmPackages.openmp.dev}/include" CACHE STRING "" FORCE)
          set(OpenMP_CXX_LIB_NAMES "omp" CACHE STRING "" FORCE)
          set(OpenMP_omp_LIBRARY "${pkgs.llvmPackages.openmp}/lib/libomp.dylib" CACHE FILEPATH "" FORCE)
          string(APPEND CMAKE_CXX_FLAGS " -I${pkgs.llvmPackages.openmp.dev}/include")
        '';
      in
      {
        imports = [
          "${inputs.devshell}/extra/language/rust.nix"
        ];
        language.rust.enableDefaultToolchain = false;
        packages = rust-toolchain
          # See the dependencies list in docs/developer-guide.md
          ++ (with pkgs; [
          lld
          protobuf
          pkg-config
          cyrus_sasl.out
          zlib

          gnumake
          cargo-binstall
          cargo-make
          cmake
          maven
          jdk17_headless

          tmux
          postgresql
          patchelf
        ] ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
          gcc
        ]) ++ lib.optionals pkgs.stdenv.isDarwin (with pkgs; [
          stdenv.cc
          llvmPackages.llvm
          llvmPackages.openmp
          blas
          lapack
          libiconv
          darwin.libresolv
          (lib.getInclude darwin.libresolv)
        ]));
        env = [
          {
            name = "PKG_CONFIG_PATH";
            value = lib.concatStringsSep ":" (
              map (pkg: "${pkg}/lib/pkgconfig") (with pkgs; [
                openssl.dev
                cyrus_sasl.dev
              ])
            );
          }
          {
            name = "LD_LIBRARY_PATH";
            value = lib.makeLibraryPath ((with pkgs; [
              openssl
              cyrus_sasl.out
              zlib
            ]) ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.libgcc.lib ]
              ++ lib.optionals pkgs.stdenv.isDarwin (with pkgs; [ blas lapack ]));
          }
          {
            name = "CMAKE_PREFIX_PATH";
            value = lib.concatStringsSep ":" (with pkgs; [
              "${openssl.dev}"
              "${cyrus_sasl.dev}"
              "${zlib.dev}"
            ]);
          }
        ] ++ lib.optionals pkgs.stdenv.isDarwin [
          {
            name = "SDKROOT";
            value = "${pkgs.apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
          }
          {
            name = "CC";
            value = "${pkgs.stdenv.cc}/bin/clang";
          }
          {
            name = "CXX";
            value = "${pkgs.stdenv.cc}/bin/clang++";
          }
          {
            name = "MACOSX_DEPLOYMENT_TARGET";
            value = "14.0";
          }
          {
            name = "CFLAGS";
            value = "-I${lib.getInclude pkgs.darwin.libresolv}/include -DBIND_4_COMPAT -DTARGET_OS_BRIDGE=0";
          }
          {
            name = "NIX_CXX";
            value = "${pkgs.stdenv.cc}/bin/clang++";
          }
          {
            name = "CMAKE_TOOLCHAIN_FILE";
            value = darwin-cmake-toolchain;
          }
          {
            name = "LIBRARY_PATH";
            value = lib.makeLibraryPath (with pkgs; [
              blas
              lapack
              llvmPackages.openmp
              libiconv
              darwin.libresolv
              openssl
              cyrus_sasl.out
              zlib
            ]);
          }
          {
            # Override devshell's aggregate Frameworks search path while
            # preserving the workspace-wide flags from .cargo/config.toml.
            name = "RUSTFLAGS";
            value = "--cfg tokio_unstable -Zhigher-ranked-assumptions";
          }
          {
            name = "RUSTDOCFLAGS";
            value = "-Zhigher-ranked-assumptions";
          }
        ];
      };
  };
}

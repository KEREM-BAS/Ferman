#
# Builds the Ferman engine (crates/ferman-api) with cargokit for macOS.
#
Pod::Spec.new do |s|
  s.name             = 'rust_lib_ferman'
  s.version          = '0.1.0'
  s.summary          = 'The Ferman Rust engine, built with cargokit.'
  s.description      = 'Builds crates/ferman-api as a static library and links it into the app.'
  s.homepage         = 'https://github.com/KEREM-BAS/Ferman'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'The Ferman Authors' => 'https://github.com/KEREM-BAS/Ferman' }

  # Classes/ holds an empty C file so CocoaPods creates a framework.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '12.0'
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'Build Rust library',
    # First argument: the engine crate, relative to this folder (app/rust_builder/macos);
    # second: the Rust library name.
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../crates/ferman-api ferman_api',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    # Tells Xcode that this step creates the static library that -force_load uses below.
    :output_files => ["${BUILT_PRODUCTS_DIR}/libferman_api.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libferman_api.a',
  }
end

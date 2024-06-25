#!/bin/bash

SWIFT_SYNTAX_VERSION=$1
SWIFT_SYNTAX_NAME="swift-syntax"
SWIFT_SYNTAX_REPOSITORY_URL="https://github.com/apple/$SWIFT_SYNTAX_NAME.git"
SEMVER_PATTERN="^[0-9]+\.[0-9]+\.[0-9]+$"
WRAPPER_NAME="SwiftSyntaxWrapper"
ARCH="arm64"
CONFIGURATION="debug"
DERIVED_DATA_PATH="$PWD/derivedData"

#
# Verify input
#

if [ -z "$SWIFT_SYNTAX_VERSION" ]; then
    echo "Swift syntax version (git tag) must be supplied as the first argument"
    exit 1
fi

if ! [[ $SWIFT_SYNTAX_VERSION =~ $SEMVER_PATTERN ]]; then
    echo "The given version ($SWIFT_SYNTAX_VERSION) does not have the right format (expected X.Y.Z)."
    exit 1
fi

#
# Print input
#

cat << EOF

Input:
swift-syntax version to build:  $SWIFT_SYNTAX_VERSION

EOF

set -eux

#
# Clone package
#

git clone --branch $SWIFT_SYNTAX_VERSION --single-branch $SWIFT_SYNTAX_REPOSITORY_URL

#
# Add static wrapper product
#

sed -i '' -E "s/(products: \[)$/\1\n    .library(name: \"${WRAPPER_NAME}\", type: .static, targets: [\"${WRAPPER_NAME}\"]),/g" "$SWIFT_SYNTAX_NAME/Package.swift"

#
# Add target for wrapper product
#

sed -i '' -E "s/(targets: \[)$/\1\n    .target(name: \"${WRAPPER_NAME}\", dependencies: [\"SwiftCompilerPlugin\", \"SwiftSyntax\", \"SwiftSyntaxBuilder\", \"SwiftSyntaxMacros\", \"SwiftSyntaxMacrosTestSupport\"]),/g" "$SWIFT_SYNTAX_NAME/Package.swift"

#
# Add exported imports to wrapper target
#

WRAPPER_TARGET_SOURCES_PATH="$SWIFT_SYNTAX_NAME/Sources/$WRAPPER_NAME"

mkdir -p $WRAPPER_TARGET_SOURCES_PATH

tee $WRAPPER_TARGET_SOURCES_PATH/ExportedImports.swift <<EOF
@_exported import SwiftCompilerPlugin
@_exported import SwiftSyntax
@_exported import SwiftSyntaxBuilder
@_exported import SwiftSyntaxMacros
EOF

MODULES=(
    "SwiftBasicFormat"
    "SwiftCompilerPlugin"
    "SwiftCompilerPluginMessageHandling"
    "SwiftDiagnostics"
    "SwiftOperators"
    "SwiftParser"
    "SwiftParserDiagnostics"
    "SwiftSyntax"
    "SwiftSyntaxBuilder"
    "SwiftSyntaxMacroExpansion"
    "SwiftSyntaxMacros"
    "SwiftSyntaxMacrosTestSupport"
    "_SwiftSyntaxTestSupport"
    "$WRAPPER_NAME"
)

PLATFORMS=(
    # xcodebuild destination    XCFramework folder name
    "macos"                     "macos-$ARCH"
    "iOS Simulator"             "ios-$ARCH-simulator"
)

XCODEBUILD_LIBRARIES=""
PLATFORMS_OUTPUTS_PATH="$PWD/outputs"

cd $SWIFT_SYNTAX_NAME

XCODEBUILD_PLATFORM_NAME="iOS"
XCFRAMEWORK_PLATFORM_NAME="ios-$ARCH"

OUTPUTS_PATH="${PLATFORMS_OUTPUTS_PATH}/${XCFRAMEWORK_PLATFORM_NAME}"
LIBRARY_PATH="${OUTPUTS_PATH}/lib${WRAPPER_NAME}.a"
XCODEBUILD_LIBRARIES="$XCODEBUILD_LIBRARIES -library $LIBRARY_PATH"

mkdir -p "$OUTPUTS_PATH"

# `swift build` cannot be used as it doesn't support building for iOS directly
xcodebuild -quiet clean build \
    -scheme $WRAPPER_NAME \
    -configuration $CONFIGURATION \
    -destination "generic/platform=$XCODEBUILD_PLATFORM_NAME" \
    -derivedDataPath $DERIVED_DATA_PATH \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    >/dev/null 2>&1

for MODULE in ${MODULES[@]}; do
    INTERFACE_PATH="$DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/${MODULE}.build/Objects-normal/$ARCH/${MODULE}.swiftinterface"
    cp $INTERFACE_PATH "$OUTPUTS_PATH"
done

TARGET_PATH="$DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos"
echo "Listing contents of $TARGET_PATH"
ls -l "$TARGET_PATH"

# FIXME: figure out how to make xcodebuild output the .a file directly. For now, we package it ourselves.
ar -crs "$LIBRARY_PATH" $DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/*.build/Objects-normal/$ARCH/Binary/*.o

ar -crs /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/outputs/ios-arm64/libSwiftSyntaxWrapper.a /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftBasicFormat.build/Objects-normal/arm64/Binary/SwiftBasicFormat.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftCompilerPlugin.build/Objects-normal/arm64/Binary/SwiftCompilerPlugin.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftCompilerPluginMessageHandling.build/Objects-normal/arm64/Binary/SwiftCompilerPluginMessageHandling.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftDiagnostics.build/Objects-normal/arm64/Binary/SwiftDiagnostics.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftOperators.build/Objects-normal/arm64/Binary/SwiftOperators.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftParser.build/Objects-normal/arm64/Binary/SwiftParser.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftParserDiagnostics.build/Objects-normal/arm64/Binary/SwiftParserDiagnostics.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntax.build/Objects-normal/arm64/Binary/SwiftSyntax.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntax509.build/Objects-normal/arm64/Binary/SwiftSyntax509.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntax510.build/Objects-normal/arm64/Binary/SwiftSyntax510.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntaxBuilder.build/Objects-normal/arm64/Binary/SwiftSyntaxBuilder.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntaxMacroExpansion.build/Objects-normal/arm64/Binary/SwiftSyntaxMacroExpansion.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntaxMacros.build/Objects-normal/arm64/Binary/SwiftSyntaxMacros.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntaxMacrosTestSupport.build/Objects-normal/arm64/Binary/SwiftSyntaxMacrosTestSupport.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/SwiftSyntaxWrapper.build/Objects-normal/arm64/Binary/SwiftSyntaxWrapper.o /Users/runner/work/swift-syntax-xcframeworks/swift-syntax-xcframeworks/derivedData/Build/Intermediates.noindex/swift-syntax.build/debug-iphoneos/_SwiftSyntaxTestSupport.build/Objects-normal/arm64/Binary/_SwiftSyntaxTestSupport.o


for ((i = 0; i < ${#PLATFORMS[@]}; i += 2)); do
    XCODEBUILD_PLATFORM_NAME="${PLATFORMS[i]}"
    XCFRAMEWORK_PLATFORM_NAME="${PLATFORMS[i+1]}"

    OUTPUTS_PATH="${PLATFORMS_OUTPUTS_PATH}/${XCFRAMEWORK_PLATFORM_NAME}"
    LIBRARY_PATH="${OUTPUTS_PATH}/lib${WRAPPER_NAME}.a"
    XCODEBUILD_LIBRARIES="$XCODEBUILD_LIBRARIES -library $LIBRARY_PATH"

    mkdir -p "$OUTPUTS_PATH"

    # `swift build` cannot be used as it doesn't support building for iOS directly
    xcodebuild -quiet clean build \
        -scheme $WRAPPER_NAME \
        -configuration $CONFIGURATION \
        -destination "generic/platform=$XCODEBUILD_PLATFORM_NAME" \
        -derivedDataPath $DERIVED_DATA_PATH \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        >/dev/null 2>&1

    for MODULE in ${MODULES[@]}; do
        INTERFACE_PATH="$DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/${MODULE}.build/Objects-normal/$ARCH/${MODULE}.swiftinterface"
        cp $INTERFACE_PATH "$OUTPUTS_PATH"
    done

    # FIXME: figure out how to make xcodebuild output the .a file directly. For now, we package it ourselves.
    ar -crs "$LIBRARY_PATH" $DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/*.build/Objects-normal/$ARCH/Binary/*.o
done

cd ..

#
# Create XCFramework
#

XCFRAMEWORK_NAME="$WRAPPER_NAME.xcframework"
XCFRAMEWORK_PATH="$XCFRAMEWORK_NAME"

xcodebuild -quiet -create-xcframework \
    $XCODEBUILD_LIBRARIES \
    -output "${XCFRAMEWORK_PATH}" >/dev/null

for ((i = 1; i < ${#PLATFORMS[@]}; i += 2)); do
    XCFRAMEWORK_PLATFORM_NAME="${PLATFORMS[i]}"
    OUTPUTS_PATH="${PLATFORMS_OUTPUTS_PATH}/${XCFRAMEWORK_PLATFORM_NAME}"
    cp $OUTPUTS_PATH/*.swiftinterface "$XCFRAMEWORK_PATH/$XCFRAMEWORK_PLATFORM_NAME"
done

zip --quiet --recurse-paths $XCFRAMEWORK_NAME.zip $XCFRAMEWORK_NAME

#
# Create package manifest
#

CHECKSUM=$(swift package compute-checksum $XCFRAMEWORK_NAME.zip)
URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/$SWIFT_SYNTAX_VERSION/$XCFRAMEWORK_NAME.zip"

tee Package.swift <<EOF
// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "$WRAPPER_NAME",
    products: [
        .library(name: "$WRAPPER_NAME", targets: ["$WRAPPER_NAME"]),
    ],
    targets: [
        .binaryTarget(
            name: "$WRAPPER_NAME",
            url: "$URL",
            checksum: "$CHECKSUM"
        ),
    ]
)
EOF

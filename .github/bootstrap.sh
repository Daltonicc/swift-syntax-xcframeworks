#!/bin/bash

SWIFT_SYNTAX_VERSION=$1
SWIFT_SYNTAX_NAME="swift-syntax"
SWIFT_SYNTAX_REPOSITORY_URL="https://github.com/apple/$SWIFT_SYNTAX_NAME.git"
SEMVER_PATTERN="^[0-9]+\.[0-9]+\.[0-9]+$"
WRAPPER_NAME="SwiftSyntaxWrapper"
ARCHS=("arm64" "x86_64")
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
    "generic/platform=macOS"          "macos"
    "generic/platform=iOS Simulator"  "ios-simulator"
    "generic/platform=iOS"            "ios"
)

XCODEBUILD_LIBRARIES=""
PLATFORMS_OUTPUTS_PATH="$PWD/outputs"

cd $SWIFT_SYNTAX_NAME

for ((i = 0; i < ${#PLATFORMS[@]}; i += 2)); do
    XCODEBUILD_PLATFORM_NAME="${PLATFORMS[i]}"
    XCFRAMEWORK_PLATFORM_NAME="${PLATFORMS[i+1]}"

    for ARCH in "${ARCHS[@]}"; do
        OUTPUTS_PATH="${PLATFORMS_OUTPUTS_PATH}/${XCFRAMEWORK_PLATFORM_NAME}-${ARCH}"
        LIBRARY_PATH="${OUTPUTS_PATH}/lib${WRAPPER_NAME}.a"
        XCODEBUILD_LIBRARIES="$XCODEBUILD_LIBRARIES -library $LIBRARY_PATH"

        mkdir -p "$OUTPUTS_PATH"

        xcodebuild clean build \
            -scheme $WRAPPER_NAME \
            -configuration $CONFIGURATION \
            -destination "$XCODEBUILD_PLATFORM_NAME" \
            -derivedDataPath $DERIVED_DATA_PATH \
            ARCHS=$ARCH \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES

        for MODULE in ${MODULES[@]}; do
            INTERFACE_PATH="$DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/${MODULE}.build/Objects-normal/$ARCH/${MODULE}.swiftinterface"
            if [ -f "$INTERFACE_PATH" ]; then
                cp $INTERFACE_PATH "$OUTPUTS_PATH"
            else
                echo "Warning: $INTERFACE_PATH does not exist"
            fi
        done

        OBJECT_FILES="$DERIVED_DATA_PATH/Build/Intermediates.noindex/swift-syntax.build/$CONFIGURATION*/${WRAPPER_NAME}.build/Objects-normal/$ARCH/*.o"
        if ls $OBJECT_FILES 1> /dev/null 2>&1; then
            ar -crs "$LIBRARY_PATH" $OBJECT_FILES
        else
            echo "Error: No object files found for $ARCH on $XCODEBUILD_PLATFORM_NAME"
            exit 1
        fi
    done
done

cd ..

#
# Create XCFramework
#

XCFRAMEWORK_NAME="$WRAPPER_NAME.xcframework"
XCFRAMEWORK_PATH="$XCFRAMEWORK_NAME"

xcodebuild -create-xcframework \
    $XCODEBUILD_LIBRARIES \
    -output "${XCFRAMEWORK_PATH}"

for ((i = 1; i < ${#PLATFORMS[@]}; i += 2)); do
    XCFRAMEWORK_PLATFORM_NAME="${PLATFORMS[i]}"
    OUTPUTS_PATH="${PLATFORMS_OUTPUTS_PATH}/${XCFRAMEWORK_PLATFORM_NAME}"
    cp $OUTPUTS_PATH/*.swiftinterface "$XCFRAMEWORK_PATH/$XCFRAMEWORK_PLATFORM_NAME"
done

zip -r $XCFRAMEWORK_NAME.zip $XCFRAMEWORK_NAME

#
# Create package manifest
#

CHECKSUM=$(swift package compute-checksum $XCFRAMEWORK_NAME.zip)
URL="https://github.com/Daltonicc/swift-syntax-xcframeworks/releases/download/$SWIFT_SYNTAX_VERSION/$XCFRAMEWORK_NAME.zip"

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

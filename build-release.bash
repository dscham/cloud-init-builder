#!/bin/bash

# Set strict mode: exit on error, error on unset variables, and fail pipelines on first error.
set -euo pipefail

# --- Configuration: Define colors for script output ---
# (No Color)
NC='\033[0m'
# Regular Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
# Bold
BOLD_YELLOW='\033[1;33m'

# --- Script Usage/Help Function ---
usage() {
    echo "Usage: $0 [-b <binary_name>] [-p <package_path>]"
    echo ""
    echo "Cross-compiles a Go application for various common platforms and architectures."
    echo ""
    echo "Options:"
    echo "  -b    The desired name for the final executable. Defaults to the current directory's name."
    echo "  -p    The path to the package to build (e.g., './cmd/mycli' or './src/main.go'). Defaults to '.'."
    echo "  -h    Display this help message."
    exit 1
}

# --- Initialize variables ---
BINARY_NAME=""
PACKAGE_PATH=""

# --- Parse Command-Line Arguments ---
while getopts ":b:p:h" opt; do
  case ${opt} in
    b )
      BINARY_NAME=$OPTARG
      ;;
    p )
      PACKAGE_PATH=$OPTARG
      ;;
    h )
      usage
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      usage
      ;;
    : )
      echo "Invalid Option: -$OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))

# --- Set Default Values for Parameters ---
if [ -z "$BINARY_NAME" ]; then
    # If BinaryName is not set, default to the current directory's name.
    BINARY_NAME=$(basename "$(pwd)")
    echo -e "${YELLOW}No binary name provided. Defaulting to '${BINARY_NAME}'.${NC}"
fi

if [ -z "$PACKAGE_PATH" ]; then
    # If PackagePath is not set, default to the current directory.
    PACKAGE_PATH="."
    echo -e "${YELLOW}No package path provided. Defaulting to '${PACKAGE_PATH}'.${NC}"
fi

# --- Main Build Logic ---

# --- Configuration ---
OUTPUT_DIR="release"
# Define the GOOS and GOARCH combinations as a space-separated string.
TARGETS="windows/amd64 linux/amd64 darwin/amd64 darwin/arm64"

echo -e "\n${CYAN}--- Go Cross-Compiler Started ---${NC}"
echo -e "${BOLD_YELLOW}Target Binary Name: ${BINARY_NAME}${NC}"
echo -e "${BOLD_YELLOW}Go Package Path:    ${PACKAGE_PATH}${NC}"

# 1. Clean up and prepare the output directory
if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
    echo -e "${YELLOW}Removed existing '${OUTPUT_DIR}' directory.${NC}"
fi
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}Created new '${OUTPUT_DIR}' directory.${NC}"

# 2. Iterate through targets and build
for target in $TARGETS; do
    # Split the target string (e.g., "linux/amd64") into OS and ARCH
    os=$(echo "$target" | cut -d'/' -f1)
    arch=$(echo "$target" | cut -d'/' -f2)

    # Determine file extension (Windows only uses .exe)
    ext=""
    if [ "$os" = "windows" ]; then
        ext=".exe"
    fi

    # Construct the final output file path and name
    output_file="${OUTPUT_DIR}/${BINARY_NAME}_${os}_${arch}${ext}"

    echo -e "\n${BOLD_YELLOW}Building for ${os}/${arch}...${NC}"

    # Set environment variables for this command only and execute the build.
    # The `if ! ...` block checks if the command fails (returns a non-zero exit code).
    if ! GOOS="$os" GOARCH="$arch" CGO_ENABLED=0 go build -o "$output_file" -ldflags "-s -w" "$PACKAGE_PATH"; then
        echo -e "${RED}-> ERROR: Build failed for ${os}/${arch}. Please check Go toolchain output.${NC}"
        exit 1
    else
        echo -e "${GREEN}-> Successfully built: ${output_file}${NC}"
    fi
done

echo -e "\n${CYAN}--- Cross-Compilation Complete ---${NC}"
echo -e "${CYAN}All resulting binaries are available in the '${OUTPUT_DIR}' directory.${NC}"
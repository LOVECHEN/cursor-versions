#!/usr/bin/env bash

set -eo pipefail

start_version="$1"
end_version="$2"
force_update="$3"

temp_path="temp"
downloads_path="downloads"

function setup_dirs() {
    mkdir -p "$temp_path"
    mkdir -p "$downloads_path"
}

function clean_data() {
    echo "Cleaning up..."
    rm -rf "$temp_path"
    rm -rf "$downloads_path"
    exit $1
}

function download_version_info() {
    echo "Downloading version information..."
    curl -s https://res.1073studio.com/cursor_versions.txt | sort -n > cursor_versions.txt
    if [ "$?" -ne 0 ]; then
        >&2 echo "Failed to download version info"
        clean_data 1
    fi
}

function download_files() {
    local version="$1"
    local buildid="$2"
    
    echo "Downloading files for version $version..."
    
    # Windows x64
    curl -L -o "$downloads_path/Cursor Setup $version - Build $buildid-x64.exe" \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20Setup%20$version%20-%20Build%20$buildid-x64.exe"
    
    # Windows ARM64
    curl -L -o "$downloads_path/Cursor Setup $version - Build $buildid-arm64.exe" \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20Setup%20$version%20-%20Build%20$buildid-arm64.exe"
    
    # Mac Universal
    curl -L -o "$downloads_path/Cursor Mac Installer ($buildid).zip" \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20Mac%20Installer%20($buildid).zip"
    
    # Mac ARM64 & x64
    curl -L -o "$downloads_path/Cursor $version - Build $buildid-arm64.dmg" \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-arm64.dmg"
    curl -L -o "$downloads_path/Cursor $version - Build $buildid-x64.dmg" \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-x64.dmg"

    # Mac ARM64 & x64
    curl -L -o "$downloads_path/Cursor $version - Build $buildid-arm64.dmg" \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-arm64-mac.zip"
    curl -L -o "$downloads_path/Cursor $version - Build $buildid-x64.dmg" \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-x64-mac.zip"
    
    # Linux
    curl -L -o "$downloads_path/cursor-$version-build-$buildid-x86_64.AppImage" \
        "https://download.todesktop.com/230313mzl4w4u92/cursor-$version-build-$buildid-x86_64.AppImage"
}

function create_release() {
    local version="$1"
    local date="$2"
    local buildid="$3"
    
    echo "Creating release for version $version..."
    gh release create "Cursor $version" \
        --title "Cursor $version ($date)" \
        --notes "Build ID: $buildid
Release Date: $date" \
        "$downloads_path"/*
}

function main() {
    setup_dirs
    download_version_info
    
    while IFS=, read -r date version buildid; do
        # 检查版本范围
        if [ ! -z "$start_version" ] && [ "$version" \< "$start_version" ]; then
            echo "Skipping version $version (before start version)"
            continue
        fi
        if [ ! -z "$end_version" ] && [ "$version" \> "$end_version" ]; then
            echo "Skipping version $version (after end version)"
            continue
        fi

        echo "Processing version $version (Build $buildid)"
        rm -rf "$downloads_path"/*
        
        download_files "$version" "$buildid"
        create_release "$version" "$date" "$buildid"
        
        echo "Successfully processed version $version"
    done < cursor_versions.txt
    
    clean_data 0
}

main 
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
    
    # 验证文件内容
    if [ ! -s cursor_versions.txt ]; then
        >&2 echo "Version info file is empty"
        clean_data 1
    fi
    
    echo "Version information downloaded successfully:"
    cat cursor_versions.txt
}

function download_files() {
    local version="$1"
    local buildid="$2"
    local valid_files=()
    
    echo "Downloading files for version $version..."
    
    # 定义下载函数
    download_and_check() {
        local url="$1"
        local output="$2"
        local min_size=10485760  # 10MB in bytes

        echo "Downloading $output..."
        if curl -L -o "$output" "$url" && [ -f "$output" ]; then
            local size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output")
            if [ "$size" -ge "$min_size" ]; then
                valid_files+=("$output")
                echo "Successfully downloaded $output ($(($size/1024/1024))MB)"
                return 0
            else
                echo "File too small: $output ($(($size/1024/1024))MB)"
                rm -f "$output"
                return 1
            fi
        else
            echo "Failed to download $output"
            rm -f "$output"
            return 1
        fi
    }
    
    # Windows x64
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20Setup%20$version%20-%20Build%20$buildid-x64.exe" \
        "$downloads_path/Cursor Setup $version - Build $buildid-x64.exe"
    
    # Windows ARM64
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20Setup%20$version%20-%20Build%20$buildid-arm64.exe" \
        "$downloads_path/Cursor Setup $version - Build $buildid-arm64.exe"
    
    # Mac Universal
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20Mac%20Installer%20($buildid).zip" \
        "$downloads_path/Cursor Mac Installer ($buildid).zip"
    
    # Mac ARM64 & x64 (DMG)
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-arm64.dmg" \
        "$downloads_path/Cursor $version - Build $buildid-arm64.dmg"
    
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-x64.dmg" \
        "$downloads_path/Cursor $version - Build $buildid-x64.dmg"
    
    # Mac ARM64 & x64 (ZIP)
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-arm64-mac.zip" \
        "$downloads_path/Cursor $version - Build $buildid-arm64-mac.zip"
    
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/Cursor%20$version%20-%20Build%20$buildid-x64-mac.zip" \
        "$downloads_path/Cursor $version - Build $buildid-x64-mac.zip"
    
    # Linux
    download_and_check \
        "https://download.todesktop.com/230313mzl4w4u92/cursor-$version-build-$buildid-x86_64.AppImage" \
        "$downloads_path/cursor-$version-build-$buildid-x86_64.AppImage"
    
    # 返回有效文件列表
    echo "${valid_files[@]}"
}

function create_release() {
    local version="$1"
    local date="$2"
    local buildid="$3"
    shift 3  # 移除前三个参数
    local files=("$@")  # 剩余的参数都是文件
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "No valid files to release"
        return 1
    fi
    
    echo "Creating release for version $version with ${#files[@]} files..."
    gh release create "Cursor $version" \
        --title "Cursor $version ($date)" \
        --notes "Build ID: $buildid
Release Date: $date" \
        "${files[@]}"
}

function main() {
    setup_dirs
    download_version_info
    
    while IFS=, read -r date version buildid; do
        # 检查是否成功读取所有字段
        if [[ -z "$date" ]] || [[ -z "$version" ]] || [[ -z "$buildid" ]]; then
            echo "Warning: Invalid line format: date='$date' version='$version' buildid='$buildid'"
            continue
        fi

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
        
        # 下载文件并获取有效文件列表
        mapfile -t valid_files < <(download_files "$version" "$buildid")
        
        # 只有当有有效文件时才创建发布
        if [ ${#valid_files[@]} -gt 0 ]; then
            create_release "$version" "$date" "$buildid" "${valid_files[@]}"
            echo "Successfully published version $version with ${#valid_files[@]} files"
        else
            echo "Skipping release for version $version - no valid files"
        fi
        
    done < cursor_versions.txt
    
    clean_data 0
}

main 
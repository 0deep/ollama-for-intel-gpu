$ErrorActionPreference = "Stop"

mkdir -Force -path .\dist | Out-Null

function checkEnv {
    if ($null -ne $env:ARCH ) {
        $script:ARCH = $env:ARCH
    } else {
        $arch=([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)
        if ($null -ne $arch) {
            $script:ARCH = ($arch.ToString().ToLower()).Replace("x64", "amd64")
        } else {
            write-host "WARNING: old powershell detected, assuming amd64 architecture - set `$env:ARCH to override"
            $script:ARCH="amd64"
        }
    }
    $script:TARGET_ARCH=$script:ARCH
    Write-host "Building for ${script:TARGET_ARCH}"
    write-host "Locating required tools and paths"
    $script:SRC_DIR=$PWD

    $script:DIST_DIR="${script:SRC_DIR}\dist\windows-${script:TARGET_ARCH}"
    $env:CGO_ENABLED="1"
    Write-Output "Checking version"
    if (!$env:VERSION) {
        $data=(git describe --tags --first-parent --abbrev=7 --long --dirty --always)
        $pattern="v(.+)"
        if ($data -match $pattern) {
            $script:VERSION=$matches[1]
        }
    } else {
        $script:VERSION=$env:VERSION
    }
    $pattern = "(\d+[.]\d+[.]\d+).*"
    if ($script:VERSION -match $pattern) {
        $script:PKG_VERSION=$matches[1]
    } else {
        $script:PKG_VERSION="0.0.0"
    }
    write-host "Building Ollama $script:VERSION with package version $script:PKG_VERSION"
    $script:JOBS=([Environment]::ProcessorCount)
}


function sycl {
    write-host "Building SYCL backend libraries"
    & cmake -B build\sycl --preset SYCL_INTEL --install-prefix $script:DIST_DIR
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
    & cmake --build build\sycl --preset SYCL_INTEL --parallel $script:JOBS
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
    & cmake --install build\sycl --component SYCL --strip
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
}


function ollama {
    mkdir -Force -path "${script:DIST_DIR}\" | Out-Null
    write-host "Building ollama CLI"
    & go build -trimpath -ldflags "-s -w -X=github.com/ollama/ollama/version.Version=$script:VERSION -X=github.com/ollama/ollama/server.mode=release" .
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
    cp .\ollama.exe "${script:DIST_DIR}\"
}

function app {
    write-host "Building Ollama App $script:VERSION with package version $script:PKG_VERSION"

    if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
        write-host "npm is not installed. Please install Node.js and npm first:"
        write-host "   Visit: https://nodejs.org/"
        exit 1
    }

    if (!(Get-Command tsc -ErrorAction SilentlyContinue)) {
        write-host "Installing TypeScript compiler..."
        npm install -g typescript
    }
    if (!(Get-Command tscriptify -ErrorAction SilentlyContinue)) {
        write-host "Installing tscriptify..."
        go install github.com/tkrajina/typescriptify-golang-structs/tscriptify@latest
    }
    if (!(Get-Command tscriptify -ErrorAction SilentlyContinue)) {
        $env:PATH="$env:PATH;$(go env GOPATH)\bin"
    }

    Push-Location app/ui/app
    npm install
    if ($LASTEXITCODE -ne 0) { 
        write-host "ERROR: npm install failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    write-host "Building React application..."
    npm run build
    if ($LASTEXITCODE -ne 0) { 
        write-host "ERROR: npm run build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # Check if dist directory exists and has content
    if (!(Test-Path "dist")) {
        write-host "ERROR: dist directory was not created by npm run build"
        exit 1
    }

    $distFiles = Get-ChildItem "dist" -Recurse
    if ($distFiles.Count -eq 0) {
        write-host "ERROR: dist directory is empty after npm run build"
        exit 1
    }

    Pop-Location

    write-host "Running go generate"
    & go generate ./...
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
	& go build -trimpath -ldflags "-s -w -H windowsgui -X=github.com/ollama/ollama/app/version.Version=$script:VERSION" -o .\dist\windows-ollama-app-${script:ARCH}.exe ./app/cmd/app/
    if ($LASTEXITCODE -ne 0) { exit($LASTEXITCODE)}
}

function deps {
    write-host "Download MSVC Redistributables"
    mkdir -Force -path "${script:SRC_DIR}\dist\\windows-arm64" | Out-Null
    mkdir -Force -path "${script:SRC_DIR}\dist\\windows-amd64" | Out-Null
    invoke-webrequest -Uri "https://aka.ms/vs/17/release/vc_redist.arm64.exe" -OutFile  "${script:SRC_DIR}\dist\windows-arm64\vc_redist.arm64.exe"
    invoke-webrequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile  "${script:SRC_DIR}\dist\windows-amd64\vc_redist.x64.exe"
    write-host "Done."
}


function zip {
    if (Test-Path -Path "${script:SRC_DIR}\dist\windows-amd64") {
        write-host "Generating stand-alone distribution zip file ${script:SRC_DIR}\dist\ollama-windows-amd64-sycl.zip"
        Compress-Archive -CompressionLevel Optimal -Path "${script:SRC_DIR}\dist\windows-amd64\*" -DestinationPath "${script:SRC_DIR}\dist\ollama-windows-amd64-sycl.zip" -Force
    }

    if (Test-Path -Path "${script:SRC_DIR}\dist\windows-arm64") {
        write-host "Generating stand-alone distribution zip file ${script:SRC_DIR}\dist\ollama-windows-arm64.zip"
        Compress-Archive -CompressionLevel Optimal -Path "${script:SRC_DIR}\dist\windows-arm64\*" -DestinationPath "${script:SRC_DIR}\dist\ollama-windows-arm64.zip" -Force
    }
}

function clean {
    Remove-Item -ea 0 -r "${script:SRC_DIR}\dist\"
    Remove-Item -ea 0 -r "${script:SRC_DIR}\build\"
}

checkEnv
try {
    if ($($args.count) -eq 0) {
        sycl
        ollama
        app
        deps
        zip
    } else {
        for ( $i = 0; $i -lt $args.count; $i++ ) {
            write-host "running build step $($args[$i])"
            & $($args[$i])
        } 
    }
} catch {
    write-host "Build Failed"
    write-host $_
} finally {
    set-location $script:SRC_DIR
    $env:PKG_VERSION=""
}
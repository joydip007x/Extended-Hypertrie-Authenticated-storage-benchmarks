# Setup MSVC environment for Extended-Hypertrie benchmarks
$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
$envVars = cmd /c "`"$vcvars`" >nul 2>&1 && set"
foreach ($line in $envVars) { if ($line -match "^([^=]+)=(.*)$") { [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process") } }

# Add to PATH
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:USERPROFILE\cmake328\cmake-3.28.1-windows-x86_64\bin;C:\Users\hp\AppData\Local\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe;$env:PATH"
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\lib"
$env:CMAKE_GENERATOR = "Ninja"

Set-Location "D:\UNB_RESEARCH_PROJECTS\Extended-Hypertrie-Authenticated-storage-benchmarks"

# Cleanup: Kill any existing benchmark processes (multiple attempts)
Write-Host "Cleaning up stale processes..."
for ($i=0; $i -lt 3; $i++) {
    Get-Process asb-main -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
}

# Cleanup: Remove temporary log/output files from previous runs
Write-Host "Cleaning up temporary files..."
Remove-Item -Path "build*.txt", "run*.txt", "rockbuild.log", "build_output.txt" -Force -ErrorAction SilentlyContinue

Write-Host "Environment configured. Starting benchmark..."
Write-Host ""

try {
    # Run the benchmark
    cargo run --release -- --no-stat -k 1m -a mpt
}
finally {
    # Cleanup: Kill the benchmark process and clean up files when done
    Write-Host ""
    Write-Host "Benchmark completed. Cleaning up..."
    Get-Process asb-main -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

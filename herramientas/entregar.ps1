# Envoltorio de PowerShell para herramientas/entregar.sh
#
# El script de entrega está en bash porque encadena flutter, git y apksigner,
# pero `bash` no suele estar en el PATH de PowerShell. Esto lo localiza solo.
#
# Uso, desde moto_taller_app/:
#
#     .\herramientas\entregar.ps1 -GeminiApiKey "tu_clave"
#
# O, si ya tienes la variable puesta en la sesión:
#
#     .\herramientas\entregar.ps1
#
# Sin clave compila igual, pero «identificar repuesto por foto» sale desactivada.

param(
    [string]$GeminiApiKey
)

$ErrorActionPreference = 'Stop'

# La clave del parámetro gana sobre la de la sesión.
if ($GeminiApiKey) {
    $env:GEMINI_API_KEY = $GeminiApiKey
}

# Sitios donde suele estar bash, en orden de preferencia.
$candidatos = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

$bash = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1

# Si no está en los sitios habituales, se busca en el PATH.
if (-not $bash) {
    $enPath = Get-Command bash -ErrorAction SilentlyContinue
    if ($enPath) { $bash = $enPath.Source }
}

if (-not $bash) {
    Write-Host "No se encontró bash.exe." -ForegroundColor Red
    Write-Host "Viene con Git para Windows: https://git-scm.com/download/win"
    exit 1
}

# La ruta del .sh se calcula desde este archivo, así que da igual desde dónde
# se invoque.
$script = Join-Path $PSScriptRoot 'entregar.sh'
$raiz = Split-Path $PSScriptRoot -Parent

Push-Location $raiz
try {
    & $bash $script
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}

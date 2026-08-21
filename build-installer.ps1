# Gera o instalador do GitLens4D.
#
# Faz a cadeia inteira, porque cada peca sozinha e facil de esquecer e o
# sintoma de esquecer e ruim (instalador que leva um .bpl velho, ou que esquece
# a pasta ui\ e entrega um plugin cujas telas abrem em branco):
#
#   1. compila o .bpl em Release   (exige a IDE fechada)
#   2. confere que a pasta ui\ esta completa
#   3. roda o ISCC
#
#   .\build-installer.ps1              # tudo
#   .\build-installer.ps1 -SkipBuild   # so reempacota o .bpl que ja existe
param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$root      = $PSScriptRoot
$installer = Join-Path $root 'installer'
$outputDir = Join-Path $installer 'dist'
$bpl       = Join-Path $root 'bin\GitLens4D.bpl'
$uiDir     = Join-Path $root 'ui'
$dproj     = Join-Path $root 'GitLens4D.dproj'

$bds     = "C:\Program Files (x86)\Embarcadero\Studio\19.0"
$msbuild = "C:\Windows\Microsoft.NET\Framework\v3.5\MSBuild.exe"

# O Inno 5 e o que esta nesta maquina; o .iss e compativel com os dois.
$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 5\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
  throw "Inno Setup nao encontrado. Instale de https://jrsoftware.org/isdl.php e rode de novo."
}

# ----------------------------------------------------------------------------
# Versao: sai do proprio .dproj, e nao de uma constante aqui.
#
# Duas fontes para o mesmo numero divergem no primeiro release apressado, e o
# instalador passaria a mentir sobre o que instala. O FileVersion do VerInfo_Keys
# da configuracao Base e o mesmo valor que o GitLens4D.Git.ProjectProvider
# reporta para a IA nas mensagens de commit.
# ----------------------------------------------------------------------------
function Get-ProjectVersion {
  param([string]$DprojPath)

  $xml = Get-Content $DprojPath -Raw
  $m = [regex]::Match($xml, '<VerInfo_Keys>([^<]*)</VerInfo_Keys>')
  if ($m.Success) {
    foreach ($pair in $m.Groups[1].Value -split ';') {
      $kv = $pair -split '=', 2
      if ($kv.Length -eq 2 -and $kv[0].Trim() -eq 'FileVersion' -and $kv[1].Trim() -ne '') {
        return $kv[1].Trim()
      }
    }
  }
  throw "Nao consegui ler o FileVersion de $DprojPath"
}

$version = Get-ProjectVersion -DprojPath $dproj
Write-Output "== GitLens4D $version =="

# ----------------------------------------------------------------------------
# 1. o pacote
# ----------------------------------------------------------------------------
if (-not $SkipBuild) {
  Write-Output "== 1/3  compilando o pacote (Release) =="

  if (Get-Process bds -ErrorAction SilentlyContinue) {
    throw "O RAD Studio esta aberto. Feche a IDE: enquanto ela roda, o bds.exe segura o .bpl e a compilacao falha com F2039."
  }

  $env:BDS          = $bds
  $env:BDSINCLUDE   = "$bds\include"
  $env:BDSCOMMONDIR = "C:\Users\Public\Documents\Embarcadero\Studio\19.0"

  Push-Location $root
  try {
    $raw  = & $msbuild GitLens4D.dproj /t:Build /p:Config=Release /p:Platform=Win32 /nologo /v:minimal 2>&1
    $code = $LASTEXITCODE
  } finally {
    Pop-Location
  }

  # MSB6002 (linha de comando longa) e consequencia da Library Path desta
  # maquina, nao do projeto -- ruido, nao sinal.
  $raw | Where-Object {
    ($_ -match '\b(error|Error|Fatal|warning|Warning|Hint)\b') -and ($_ -notmatch 'MSB6002')
  }

  if ($code -ne 0) {
    throw "A compilacao do pacote falhou (exit $code)."
  }
}

if (-not (Test-Path $bpl)) {
  throw "$bpl nao existe. Rode sem -SkipBuild."
}

# ----------------------------------------------------------------------------
# 2. a pasta ui\
#
# Conferida arquivo por arquivo de proposito: uma pagina que falta nao quebra
# o build nem o instalador -- so aparece la na frente, como uma tela em branco
# dentro da IDE do usuario.
# ----------------------------------------------------------------------------
Write-Output "== 2/3  conferindo ui\ =="

$required = @('status.html', 'diff.html', 'history.html', 'settings.html', 'pr.html',
              'base.css', 'diff-render.js')
$missing = $required | Where-Object { -not (Test-Path (Join-Path $uiDir $_)) }
if ($missing) {
  throw "Faltando em ui\: $($missing -join ', ')"
}
Write-Output "   $($required.Count) arquivos ok"

# ----------------------------------------------------------------------------
# 3. o instalador
# ----------------------------------------------------------------------------
Write-Output "== 3/3  empacotando =="

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$issc = & $iscc `
  "/DAppVersion=$version" `
  "/DSourceRoot=$root" `
  "/DOutputDir=$outputDir" `
  (Join-Path $installer 'GitLens4D.iss')

if ($LASTEXITCODE -ne 0) {
  $issc
  throw "ISCC falhou (exit $LASTEXITCODE)."
}

$setup = Join-Path $outputDir "GitLens4D-$version-setup.exe"
if (-not (Test-Path $setup)) {
  $issc
  throw "ISCC terminou sem erro mas $setup nao apareceu."
}

Write-Output ""
Write-Output "OK - $setup"
Get-Item $setup | ForEach-Object {
  Write-Output ("   {0:N0} bytes  {1}" -f $_.Length, $_.LastWriteTime)
}
Write-Output ""
Write-Output "Instala por usuario (sem admin), em %LOCALAPPDATA%\Programs\GitLens4D,"
Write-Output "e registra o pacote em HKCU\...\BDS\19.0\Known Packages."

# Script de Deploy Automatizado - Pomodoro Dev Tracker
# Executa compilacao limpa, sincroniza versoes e envia para o GitHub

$ErrorActionPreference = "Stop"

# Caminhos locais
$projetoNome = "pomodoro_flutter"
$pubspecPath = "$projetoNome\pubspec.yaml"
$updateServicePath = "$projetoNome\lib\core\services\update_service.dart"
$versionJsonPath = "version.json"
$tempPath = "C:\Users\Usuario\pomodoro_flutter_temp"

Write-Host "========== INICIANDO PIPELINE DE DEPLOY AUTOMATIZADO ==========" -ForegroundColor Cyan

# 1. Extrai a versao atual do pubspec.yaml
if (!(Test-Path $pubspecPath)) {
    Write-Error "Arquivo pubspec.yaml nao encontrado em $pubspecPath!"
}

$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match 'version:\s*([^\s+]+)') {
    $versao = $Matches[1]
    Write-Host "Versao detectada no pubspec.yaml: v$versao" -ForegroundColor Green
} else {
    Write-Error "Nao foi possivel encontrar a chave 'version' no pubspec.yaml!"
}

# 2. Sincroniza a versao no update_service.dart de forma automatica
Write-Host "Sincronizando versao no codigo Dart..." -ForegroundColor Yellow
$updateContent = Get-Content $updateServicePath -Raw
$newUpdateContent = $updateContent -replace 'static const String versaoAtual = "[^"]+"', "static const String versaoAtual = `"$versao`""
[System.IO.File]::WriteAllText((Resolve-Path $updateServicePath), $newUpdateContent, [System.Text.Encoding]::UTF8)

# 3. Atualiza o version.json na raiz do repositorio
Write-Host "Atualizando arquivo version.json..." -ForegroundColor Yellow
$jsonObj = @{
    version = $versao
    android_url = "https://raw.githubusercontent.com/Mp-resende/App_Pomodoro_Notion/main/releases/app-arm64-v8a-release.apk"
    windows_url = "https://raw.githubusercontent.com/Mp-resende/App_Pomodoro_Notion/main/releases/windows/pomodoro_notion.exe"
}
$jsonContent = ConvertTo-Json $jsonObj -Depth 4
[System.IO.File]::WriteAllText((New-Item -Path $versionJsonPath -Force).FullName, $jsonContent, [System.Text.Encoding]::UTF8)

# 4. Executa os testes de unidade locais antes de compilar
Write-Host "Executando testes unitarios..." -ForegroundColor Yellow
cd $projetoNome
& C:\Users\Usuario\flutter\bin\flutter.bat test
cd ..

# 5. Prepara a pasta temporaria de compilacao (evitando caminhos acentuados do compilador Dart)
Write-Host "Limpando e preparando pasta temporaria de compilacao..." -ForegroundColor Yellow
if (Test-Path $tempPath) {
    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

# Copia de forma rapida usando Robocopy (nativo do Windows, ignora arquivos desnecessarios)
Write-Host "Copiando projeto para pasta temporaria ASCII..." -ForegroundColor Yellow
robocopy "$projetoNome" "$tempPath" /XD build .dart_tool .git /XF .env /S /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

# Remove links simbolicos remanescentes da pasta ephemeral temporaria
Remove-Item -Path "$tempPath\windows\flutter\ephemeral" -Recurse -Force -ErrorAction SilentlyContinue

# 6. Executa as compilacoes na pasta temporaria
Write-Host "Compilando APK do Android..." -ForegroundColor Yellow
cd $tempPath
& C:\Users\Usuario\flutter\bin\flutter.bat build apk --split-per-abi
cd $PSScriptRoot

Write-Host "Compilando executavel do Windows..." -ForegroundColor Yellow
cd $tempPath
& C:\Users\Usuario\flutter\bin\flutter.bat build windows
cd $PSScriptRoot

# 7. Fecha processos antigos do app para destravar arquivos de escrita no Windows
Write-Host "Fechando processos antigos do aplicativo..." -ForegroundColor Yellow
Stop-Process -Name "pomodoro_notion" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 8. Copia os binarios finais compilados para a pasta de releases oficiais e pasta de build local
Write-Host "Copiando artefatos finais para a pasta de releases oficiais..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "releases\windows" -Force | Out-Null

Copy-Item -Path "$tempPath\build\windows\x64\runner\Release\*" -Destination "releases\windows\" -Recurse -Force
Copy-Item -Path "$tempPath\build\app\outputs\flutter-apk\*.apk" -Destination "releases\" -Force

Write-Host "Sincronizando pasta de build local para testes locais..." -ForegroundColor Yellow
# Garante as pastas locais
New-Item -ItemType Directory -Path "pomodoro_flutter\build\windows\x64\runner\Release" -Force | Out-Null
New-Item -ItemType Directory -Path "pomodoro_flutter\build\app\outputs\flutter-apk" -Force | Out-Null

# Copia de volta
Copy-Item -Path "$tempPath\build\windows\x64\runner\Release\*" -Destination "pomodoro_flutter\build\windows\x64\runner\Release\" -Recurse -Force
Copy-Item -Path "$tempPath\build\app\outputs\flutter-apk\*" -Destination "pomodoro_flutter\build\app\outputs\flutter-apk\" -Recurse -Force

# 9. Limpa a pasta temporaria de build
Write-Host "Removendo arquivos temporarios..." -ForegroundColor Yellow
Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue

# 10. Executa o deploy Git e Push para o GitHub
Write-Host "Iniciando publicacao no GitHub..." -ForegroundColor Cyan

# Pergunta pela mensagem de commit
$commitMsg = Read-Host "Digite a mensagem do Commit (ou pressione Enter para usar padrao 'release: v$versao')"
if ([string]::IsNullOrWhiteSpace($commitMsg)) {
    $commitMsg = "release: v$versao"
}

git add .
git commit -m $commitMsg
Write-Host "Enviando dados para o GitHub (push)..." -ForegroundColor Yellow
git push origin main

Write-Host "========== DEPLOY AUTOMATICO CONCLUIDO COM SUCESSO! ==========" -ForegroundColor Green
Write-Host "Os novos instaladores e o arquivo version.json ja estao disponiveis no seu GitHub." -ForegroundColor Green

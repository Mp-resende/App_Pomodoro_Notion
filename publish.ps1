# Script de Deploy Automatizado - Pomodoro Dev Tracker
# Executa compilação limpa, sincroniza versões e envia para o GitHub

$ErrorActionPreference = "Stop"

# Caminhos locais
$projetoNome = "pomodoro_flutter"
$pubspecPath = "$projetoNome\pubspec.yaml"
$updateServicePath = "$projetoNome\lib\core\services\update_service.dart"
$versionJsonPath = "version.json"
$tempPath = "C:\Users\Usuario\pomodoro_flutter_temp"

Write-Host "========== 🚀 INICIANDO PIPELINE DE DEPLOY AUTOMATIZADO ==========" -ForegroundColor Cyan

# 1. Extrai a versão atual do pubspec.yaml
if (!(Test-Path $pubspecPath)) {
    Write-Error "Arquivo pubspec.yaml não encontrado em $pubspecPath!"
}

$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match 'version:\s*([^\s+]+)') {
    $versao = $Matches[1]
    Write-Host "ℹ️ Versão detectada no pubspec.yaml: v$versao" -ForegroundColor Green
} else {
    Write-Error "Não foi possível encontrar a chave 'version' no pubspec.yaml!"
}

# 2. Sincroniza a versão no update_service.dart de forma automática
Write-Host "🔄 Sincronizando versão no código Dart..." -ForegroundColor Yellow
$updateContent = Get-Content $updateServicePath -Raw
$newUpdateContent = $updateContent -replace 'static const String versaoAtual = "[^"]+"', "static const String versaoAtual = `"$versao`""
[System.IO.File]::WriteAllText((Resolve-Path $updateServicePath), $newUpdateContent, [System.Text.Encoding]::UTF8)

# 3. Atualiza o version.json na raiz do repositório
Write-Host "🔄 Atualizando arquivo version.json..." -ForegroundColor Yellow
$jsonObj = @{
    version = $versao
    android_url = "https://raw.githubusercontent.com/Mp-resende/App_Pomodoro_Notion/main/pomodoro_flutter/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    windows_url = "https://raw.githubusercontent.com/Mp-resende/App_Pomodoro_Notion/main/pomodoro_flutter/build/windows/x64/runner/Release/pomodoro_notion.exe"
}
$jsonContent = ConvertTo-Json $jsonObj -Depth 4
[System.IO.File]::WriteAllText((New-Item -Path $versionJsonPath -Force).FullName, $jsonContent, [System.Text.Encoding]::UTF8)

# 4. Executa os testes de unidade locais antes de compilar
Write-Host "🧪 Executando testes unitários..." -ForegroundColor Yellow
cd $projetoNome
& C:\Users\Usuario\flutter\bin\flutter.bat test
cd ..

# 5. Prepara a pasta temporária de compilação (evitando caminhos acentuados do compilador Dart)
Write-Host "🧹 Limpando e preparando pasta temporária de compilação..." -ForegroundColor Yellow
if (Test-Path $tempPath) {
    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

# Copia de forma rápida usando Robocopy (nativo do Windows, ignora arquivos desnecessários)
Write-Host "📁 Copiando projeto para pasta temporária ASCII..." -ForegroundColor Yellow
robocopy "$projetoNome" "$tempPath" /XD build .dart_tool .git /XF .env /S /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null

# Remove links simbólicos remanescentes da pasta ephemeral temporária
Remove-Item -Path "$tempPath\windows\flutter\ephemeral" -Recurse -Force -ErrorAction SilentlyContinue

# 6. Executa as compilações na pasta temporária
Write-Host "🛠️ Compilando APK do Android..." -ForegroundColor Yellow
cd $tempPath
& C:\Users\Usuario\flutter\bin\flutter.bat build apk --split-per-abi
cd $PSScriptRoot

Write-Host "🛠️ Compilando executável do Windows..." -ForegroundColor Yellow
cd $tempPath
& C:\Users\Usuario\flutter\bin\flutter.bat build windows
cd $PSScriptRoot

# 7. Fecha processos antigos do app para destravar arquivos de escrita no Windows
Write-Host "🔒 Fechando processos antigos do aplicativo..." -ForegroundColor Yellow
Stop-Process -Name "pomodoro_notion" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 8. Copia os binários finais compilados de volta para a pasta de trabalho oficial
Write-Host "🚚 Copiando artefatos finais para a pasta oficial do projeto..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$projetoNome\build\windows\x64\runner" -Force | Out-Null
New-Item -ItemType Directory -Path "$projetoNome\build\app\outputs" -Force | Out-Null

Copy-Item -Path "$tempPath\build\windows\x64\runner\Release" -Destination "$projetoNome\build\windows\x64\runner\" -Recurse -Force
Copy-Item -Path "$tempPath\build\app\outputs\flutter-apk" -Destination "$projetoNome\build\app\outputs\" -Recurse -Force

# 9. Limpa a pasta temporária de build
Write-Host "🧹 Removendo arquivos temporários..." -ForegroundColor Yellow
Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue

# 10. Executa o deploy Git e Push para o GitHub
Write-Host "🐙 Iniciando publicação no GitHub..." -ForegroundColor Cyan

# Pergunta pela mensagem de commit
$commitMsg = Read-Host "Digite a mensagem do Commit (ou pressione Enter para usar padrão 'release: v$versao')"
if ([string]::IsNullOrWhiteSpace($commitMsg)) {
    $commitMsg = "release: v$versao"
}

git add .
git commit -m $commitMsg
Write-Host "📤 Enviando dados para o GitHub (push)..." -ForegroundColor Yellow
git push origin main

Write-Host "========== 🎉 DEPLOY AUTOMÁTICO CONCLUÍDO COM SUCESSO! ==========" -ForegroundColor Green
Write-Host "Os novos instaladores e o arquivo version.json já estão disponíveis no seu GitHub." -ForegroundColor Green

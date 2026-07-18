# Guia de Atualização de Versão (Pomodoro Notion)

Este documento explica o fluxo e os arquivos envolvidos no processo de atualização de versão do aplicativo, cobrindo tanto o ambiente local de desenvolvimento quanto o repositório Git (GitHub).

---

## 📌 Visão Geral do Fluxo

A versão do aplicativo é centralizada no arquivo de configuração do Flutter. O processo de compilação e deploy é automatizado através do script do PowerShell `publish.ps1`. 

O script resolve um problema crítico do Windows: compiladores do Flutter/Dart falham quando executados em caminhos com caracteres acentuados (como a pasta `Programação`). Por isso, o build é feito em uma pasta temporária neutra e depois os arquivos são copiados de volta para o projeto.

---

## 🛠️ Passo a Passo para Atualizar a Versão

Sempre que fizer alterações no código e quiser gerar uma nova release (versão):

### 1. Atualize a versão no Flutter (Manual)
Abra o arquivo [pomodoro_flutter/pubspec.yaml](file:///c:/Users/Usuario/Desktop/Programa%C3%A7%C3%A3o/App_Pomodoro_Notion/pomodoro_flutter/pubspec.yaml) e altere a linha `version`:
```yaml
version: 1.1.3+1
```
* O número antes do `+` (`1.1.3`) é a versão visível do app.
* O número após o `+` (`1`) é o número do build (usado pelas lojas e controle interno). Incremente ambos conforme necessário.

### 2. Execute o Script de Publicação (Manual)
Abra o terminal PowerShell na raiz do projeto e execute:
```powershell
./publish.ps1
```

---

## 🔄 O que o script `publish.ps1` faz automaticamente?

Ao rodar o `./publish.ps1`, ele realiza os seguintes passos sem que você precise intervir:

1. **Lê a nova versão** diretamente do `pubspec.yaml`.
2. **Atualiza o código do aplicativo**: Altera a variável `versaoAtual` no arquivo [update_service.dart](file:///c:/Users/Usuario/Desktop/Programa%C3%A7%C3%A3o/App_Pomodoro_Notion/pomodoro_flutter/lib/core/services/update_service.dart) para a nova versão. Isso garante que a tela sobre/versão do app mostre o número correto.
3. **Atualiza as URLs de Atualização**: Edita o arquivo [version.json](file:///c:/Users/Usuario/Desktop/Programa%C3%A7%C3%A3o/App_Pomodoro_Notion/version.json) na raiz do projeto com o número da nova versão e os links para download direto no GitHub.
4. **Executa Testes**: Roda os testes unitários do Flutter para garantir que nada foi quebrado.
5. **Prepara o Build**: Copia o projeto para `C:\Users\Usuario\pomodoro_flutter_temp` (caminho ASCII sem acentos).
6. **Compila os Binários**:
   * Gera o executável Windows (`.exe`).
   * Gera o instalador Android (`.apk`).
7. **Sincroniza os Arquivos Finais**:
   * **No Git (Releases)**: Copia os arquivos compilados para a pasta `releases/` (ex: `releases/windows/pomodoro_notion.exe` e `releases/app-arm64-v8a-release.apk`).
   * **No Local (Ambiente de Testes)**: Copia os mesmos arquivos de volta para a pasta de build interna do projeto (`pomodoro_flutter/build/...`). Isso garante que os seus atalhos locais e execução pelo VS Code rodem a versão atualizada.
8. **Publica no GitHub**: Executa o `git add`, pede a mensagem de commit no terminal (se der Enter, usa um padrão automático) e faz o `git push origin main`.

---

## 📂 Arquivos Envolvidos e Suas Funções

| Arquivo/Pasta | Tipo de Atualização | Função |
| :--- | :--- | :--- |
| **`pomodoro_flutter/pubspec.yaml`** | ✏️ **Manual** | A fonte da verdade. Define a versão oficial do projeto. |
| **`pomodoro_flutter/lib/core/services/update_service.dart`** | 🤖 **Automático** | Contém a versão estática que o app usa em tempo de execução para verificar se há atualizações no servidor. |
| **`version.json`** | 🤖 **Automático** | Arquivo lido pelo aplicativo instalado para comparar a versão local com a versão remota disponível no GitHub. |
| **`releases/`** | 🤖 **Automático** | Pasta rastreada pelo Git que contém os arquivos finais de instalação (`.exe` e `.apk`) que os usuários irão baixar. |
| **`pomodoro_flutter/build/`** | 🤖 **Automático** | Pasta local (ignorada pelo Git) onde ficam os executáveis de testes locais e execução direta por IDEs. |

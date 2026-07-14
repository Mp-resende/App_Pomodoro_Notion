# 🍅 Pomodoro Dev Tracker (Flutter Version)

**Cronômetro Pomodoro premium adaptativo para Windows e Android com integração nativa ao Notion e atualizações automáticas.**

Este aplicativo é a evolução completa do projeto legado em Python. Reescrevido do zero em **Flutter e Dart**, o Pomodoro Dev Tracker oferece uma interface de usuário moderna com tema escuro (Dark Slate/Deep Blue), efeitos de glow neon, anel de progresso circular animado e suporte multiplataforma nativo de alto desempenho.

---

## 🚀 Funcionalidades Principais

*   🖥️📱 **Multiplataforma:** Tamanho fixo adaptativo premium em `520x800` no Windows e responsividade em tela cheia no Android.
*   🔄 **Integração Notion Sem Fios:** Envia os registros de sessões de foco diretamente para o seu banco de dados Notion de forma assíncrona (não trava a interface gráfica).
*   💾 **Cache Offline Inteligente:** Se você estiver sem internet, o aplicativo salva as sessões localmente e faz a sincronização com o Notion de forma 100% automática assim que a conexão for restabelecida.
*   ⚙️ **Sistema Híbrido de Atualização Automática (In-App Auto-Update):** 
    *   **Silencioso:** Checa por novas atualizações no GitHub apenas 1 vez a cada 24 horas para preservar a bateria do celular.
    *   **Manual:** Botão de busca forçada rápida dentro das Configurações do app.
    *   **Prático:** Exibe um banner neon discreto na tela inicial. Ao tocar, abre o navegador baixando e instalando o novo pacote por cima de forma segura.
*   🎯 **Relações de Banco de Dados:** Permite vincular a sua sessão de foco a outras tabelas relacionadas no Notion (como Projetos ou Tarefas) antes de dar o play.
*   🔔 **Notificações e Alarmes Sonoros:** Dispara alarmes sonoros nativos de celular e vibração no Android (mesmo com a tela apagada) e beeps do sistema no Windows.

---

## 📁 Estrutura de Distribuição (Builds Prontos)

Os arquivos finais compilados prontos para instalação e uso estão disponíveis na pasta do projeto:

### 📱 Android (Celular)
Recomendado para celulares modernos (arquitetura 64 bits):
*   👉 **[app-arm64-v8a-release.apk](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/pomodoro_flutter/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk)**
*   *Instalação:* Transfira o arquivo para o seu celular e execute para instalar. Certifique-se de permitir a instalação de fontes externas caso o Android solicite.

### 🖥️ Windows (Desktop)
*   👉 **[pomodoro_notion.exe](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/pomodoro_flutter/build/windows/x64/runner/Release/pomodoro_notion.exe)** (localizado na pasta [Release (Windows)](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/pomodoro_flutter/build/windows/x64/runner/Release/))
*   *Execução:* Execute o arquivo `.exe` mantendo-o dentro da pasta com as respectivas DLLs de acompanhamento.

---

## 🔑 Configuração do Notion

Para integrar o aplicativo ao seu Notion, consulte o nosso manual de configuração detalhado:
👉 **[📚 Guia de Configuração do Notion](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/NOTION_SETUP.md)**

---

## 🔧 Desenvolvimento e Compilação

Caso deseje modificar o código e recompilar o projeto:

### Pré-requisitos
*   Flutter SDK (^3.12.2)
*   Android SDK configurado (para builds do Android)
*   Visual Studio com C++ Build Tools (para builds do Windows)

### Executar Testes Unitários
Para verificar a integridade da lógica de negócios e persistência:
```bash
cd pomodoro_flutter
flutter test
```

### Compilar Nova Release do Android (APK)
```bash
cd pomodoro_flutter
flutter build apk --split-per-abi
```

### Compilar Nova Release do Windows
```bash
cd pomodoro_flutter
flutter build windows
```
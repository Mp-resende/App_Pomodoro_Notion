# 🍅 Pomodoro Dev Tracker (Versão Flutter)

**Cronômetro Pomodoro premium adaptativo para Windows e Android com integração nativa ao Notion, estatísticas avançadas e atualizações automáticas.**

Este aplicativo é a evolução completa do projeto legado em Python. Reescrevido do zero em **Flutter e Dart**, o Pomodoro Dev Tracker oferece uma interface de usuário moderna com tema escuro (*Dark Slate/Deep Blue*), efeitos de glow neon, anel de progresso circular animado e suporte multiplataforma nativo de alto desempenho.

---

## 🚀 Funcionalidades Principais

*   🖥️📱 **Multiplataforma Premium:** Tamanho fixo adaptativo de `520x800` no Windows (bloqueado para evitar distorções de layout) e interface responsiva em tela cheia no Android.
*   🔄 **Integração Notion Sem Fios:** Envia os registros de sessões de foco diretamente para o seu banco de dados Notion de forma assíncrona, garantindo que o aplicativo nunca trave durante requisições de rede.
*   💾 **Cache Offline Inteligente:** Se você estiver sem internet, o aplicativo salva as sessões localmente de forma segura. A sincronização com o Notion ocorre automaticamente assim que a conexão for restabelecida ou manualmente através das Configurações.
*   ⚙️ **Sistema Híbrido de Atualização Automática (In-App Auto-Update):** 
    *   **Silencioso:** Checa por novas atualizações no repositório do GitHub apenas uma vez a cada 24 horas para preservar a bateria do dispositivo.
    *   **Manual:** Opção de busca forçada instantânea nas Configurações.
    *   **Notificação Fluida:** Exibe um banner neon discreto na tela inicial quando um update é detectado. Ao clicar, abre o navegador para download imediato.
*   🎯 **Relações de Banco de Dados Notion:** Permite vincular a sua sessão de foco a outras tabelas relacionadas no Notion (como Projetos ou Tópicos de Estudo) diretamente na tela inicial antes de iniciar o timer.
*   🔔 **Notificações e Alarmes Sonoros:** Alarmes sonoros nativos de celular e vibração no Android (com suporte a execução em segundo plano com a tela apagada) e beeps do sistema com notificações nativas no Windows.

---

## 📊 Painel de Estatísticas Avançado (Dashboard)

O app conta com um painel estatístico interativo que se conecta a três tabelas do Notion de forma síncrona com cache local:

*   📈 **Gráficos Interativos (FL Chart):**
    *   **Distribuição por Matéria:** Gráfico de pizza que exibe a porcentagem e o tempo dedicado a cada matéria estudada.
    *   **Distribuição por Tipo de Estudo:** Gráfico de pizza indicando a divisão do foco em *Teoria*, *Prática* ou *Revisão*.
    *   **Evolução Diária:** Gráfico de barras verticais indicando as horas focadas por dia no período selecionado.
    *   **Distribuição Tecnológica:** Gráfico de barras horizontais indicando a quantidade de horas focada em cada tecnologia (ex: Dart, Flutter, Python, SQL).
*   🔍 **Barra de Filtros Dinâmicos em Tempo Real:**
    *   Filtro por matérias específicas para detalhamento de foco.
    *   Filtro por períodos de tempo rápidos: *Todo o Histórico*, *Últimos 7 Dias*, *Esta Semana (Segunda a Domingo)* e *Semana Passada*.
    *   **Período Personalizado:** Selecionador de data nativo em formato de calendário para filtrar qualquer intervalo de datas específico.
*   📋 **Card de Detalhamento por Matéria:** Ao filtrar por uma matéria individual, os gráficos de pizza irrelevantes dão lugar a um card analítico contendo:
    *   O tempo total focado na matéria selecionada.
    *   A quantidade de sessões de estudo finalizadas.
    *   A média de tempo por sessão dessa matéria.
    *   Uma barra de progresso visual comparando as horas estudadas com a **Meta Semanal** configurada diretamente no Notion para aquela matéria.
*   🗂️ **Listagem de Tópicos Estudados:** Exibe uma lista de tópicos específicos estudados dentro da matéria selecionada, ordenados pelo tópico com maior tempo acumulado, contendo a minutagem e o tipo de estudo (*Teoria*, *Prática*, *Revisão*).
*   ⚡ **Cache de Alto Desempenho:** Os dados carregados do Notion são salvos localmente em cache (`dashboard_cache.json`). Isso permite abrir o painel instantaneamente e navegar pelos gráficos sem atrasos de rede.

---

## 🖥️ Exclusividades da Versão Windows

A versão desktop foi projetada para atuar como um utilitário de produtividade discreto e integrado ao sistema operacional:

*   📥 **Minimizar para a Bandeja do Sistema (System Tray):** Ao minimizar ou fechar o app, ele pode continuar rodando silenciosamente em segundo plano na barra de tarefas (próximo ao relógio). Clicando com o botão direito, o usuário pode abrir o app, pausar/iniciar o timer ou fechar a aplicação.
*   📺 **Mini-Player Flutuante (Picture-in-Picture):** 
    *   Um botão na tela inicial transforma o app em uma janela minúscula e compacta.
    *   Fica fixado **Sempre no Topo (Always on Top)** para que você possa acompanhar o tempo restante e controlar o timer (Play, Pause, Pular) enquanto trabalha.
    *   Pode ser arrastado livremente para qualquer canto do monitor.
*   🔒 **Persistência Robusta de Diretórios:** O app resolve o local do executável real (`File(Platform.resolvedExecutable).parent`) para salvar as configurações locais (`config.json`, histórico e caches). Isso impede a perda de credenciais ou salvamento em diretórios protegidos do sistema (como `System32`) quando o app é aberto por atalhos ou scripts.

---

## 📁 Estrutura de Distribuição (Builds Prontos)

Os arquivos finais compilados prontos para instalação e uso estão disponíveis no repositório:

### 📱 Android (Celular)
Recomendado para celulares modernos (arquitetura 64 bits):
*   👉 **[app-arm64-v8a-release.apk](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/releases/app-arm64-v8a-release.apk)**
*   *Instalação:* Transfira o arquivo para o seu celular e execute para instalar. Certifique-se de permitir a instalação de fontes externas caso o Android solicite.

### 🖥️ Windows (Desktop)
*   👉 **[pomodoro_notion.exe](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/releases/windows/pomodoro_notion.exe)** (localizado na pasta [Releases Windows](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/releases/windows/))
*   *Execução:* Execute o arquivo `.exe` mantendo-o dentro de sua pasta original contendo as respectivas DLLs de acompanhamento para funcionamento correto dos plug-ins do sistema.

---

## 🔑 Configuração do Notion

Para integrar o aplicativo ao seu Notion, consulte o nosso manual de configuração detalhado contendo a modelagem das tabelas adicionais de matérias e estudos diários para o Dashboard:
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

### Pipeline de Deploy Automatizado
O projeto possui um script inteligente em PowerShell que resolve problemas do compilador Dart com caminhos que contêm acentos (como `Programação`). O script copia o código para um diretório temporário ASCII, realiza o build limpo do Windows e do Android (em todas as arquiteturas), sincroniza os números de versões nos arquivos locais e envia os binários compilados direto para o GitHub de forma segura.

Para rodar o deploy automático:
```powershell
./publish.ps1
```

Para mais detalhes sobre as regras de versão do repositório, consulte o manual de atualização:
👉 **[⚙️ Guia de Atualização de Versão](file:///c:/Users/Usuario/Desktop/Programação/App_Pomodoro_Notion/VERSION_UPDATE.md)**
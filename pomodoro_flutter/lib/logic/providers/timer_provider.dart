import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/notion_service.dart';
import '../../core/services/update_service.dart';
import '../../data/models/pomodoro_config.dart';
import 'package:window_manager/window_manager.dart';

class TimerProvider with ChangeNotifier {
  final StorageService storageService;
  final NotificationService notificationService;
  NotionService? notionService;

  // Estado de Atualização
  bool novaVersaoDisponivel = false;
  String urlAtualizacao = "";
  String tagNovaVersao = "";

  // Estado do Timer
  int tempoRestante = 25 * 60; // segundos
  bool rodando = false;
  bool pausado = false;
  DateTime? tempoInicio;
  DateTime? tempoFim;
  bool modoDescanso = false;
  String? tipoDescanso; // "curto" ou "longo"
  int pomodorosCompletados = 0;
  int pomodorosHoje = 0;

  // Dados da Sessão Focada
  String tarefaAtual = "";
  String categoriaAtual = "";
  String? campoRelacaoSelecionado;
  String? idRelacaoSelecionado;

  // Configurações & Histórico
  PomodoroConfig config = PomodoroConfig();
  List<String> historicoTarefas = [];
  bool inicializado = false;

  // Visualização de Status
  String labelStatus = "Pronto para começar";
  String textStatusColor = "#4CAF50"; // Verde
  String labelDecorrido = "";
  double progresso = 0.0;
  bool sessaoEmFinalizacao = false;

  // Loop do Timer
  Timer? _ticker;

  // Credenciais do Notion (podem vir do .env ou do config.json)
  String notionApiKey = "";
  String notionDatabaseId = "";

  // Callbacks para eventos da UI
  VoidCallback? onSessionFinished;
  VoidCallback? onBreakFinished;

  TimerProvider({
    required this.storageService,
    required this.notificationService,
  });
  // Nota: inicializar() é chamado explicitamente no main.dart com await para evitar race conditions.

  // Carrega configurações, histórico, contador e credenciais
  Future<void> inicializar() async {
    if (inicializado) return;

    // 1. Carrega configurações do arquivo config.json
    final configData = await storageService.readJson(StorageService.configFile);
    if (configData is Map<String, dynamic>) {
      config = PomodoroConfig.fromJson(configData);
      notionApiKey = configData['notion_api_key']?.toString() ?? "";
      notionDatabaseId = configData['notion_database_id']?.toString() ?? "";
      _ultimaChecagemUpdateStr = configData['ultima_checagem_update']?.toString() ?? "";
    } else {
      config = PomodoroConfig();
    }

    // 2. Tenta ler o arquivo .env (apenas no Windows) para manter compatibilidade com chaves locais
    if (Platform.isWindows) {
      final env = await _lerDotEnv();
      if (env.containsKey("NOTION_API_KEY")) {
        notionApiKey = env["NOTION_API_KEY"]!;
      }
      if (env.containsKey("DATABASE_ID")) {
        notionDatabaseId = env["DATABASE_ID"]!;
      }
    }

    // 3. Inicializa o serviço do Notion
    _configurarNotionService();

    // 4. Carrega histórico de autocomplete
    final histData = await storageService.readJson(StorageService.historicoFile);
    if (histData is List) {
      historicoTarefas = histData.map((e) => e.toString()).toList();
    }

    // 5. Carrega contador diário
    await _carregarContadorHoje();

    tempoRestante = config.tempoTrabalho * 60;
    inicializado = true;
    notifyListeners();

    // Escuta eventos de botões interativos das notificações (Android)
    NotificationService.onActionSelected.stream.listen((actionId) {
      if (actionId == 'action_comecar_descanso') {
        iniciarDescanso(precisaLongBreak());
      } else if (actionId == 'action_pular_descanso') {
        pularDescanso();
      }
    });

    // Trata ação de notificação pendente (Cold Start)
    if (NotificationService.acaoPendente != null) {
      final acao = NotificationService.acaoPendente;
      NotificationService.acaoPendente = null; // Limpa imediatamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (acao == 'action_comecar_descanso') {
          iniciarDescanso(precisaLongBreak());
        } else if (acao == 'action_pular_descanso') {
          pularDescanso();
        }
      });
    }

    // 6. Sincroniza sessões salvas offline (background)
    if (notionService != null) {
      _sincronizarOfflineEmBackground();
    }

    // 7. Checa se existem atualizações disponíveis no GitHub
    _checarAtualizacaoSilenciosa();
  }

  String _ultimaChecagemUpdateStr = "";

  Future<void> _checarAtualizacaoSilenciosa() async {
    // 1. Verifica se já rodamos a checagem automática nas últimas 24 horas
    if (_ultimaChecagemUpdateStr.isNotEmpty) {
      try {
        final ultimaData = DateTime.parse(_ultimaChecagemUpdateStr);
        final diferenca = DateTime.now().difference(ultimaData);
        if (diferenca.inHours < 24) {
          // Menos de 24 horas desde a última checagem automática de sucesso.
          // Retorna silenciosamente sem fazer chamadas de rede.
          return;
        }
      } catch (_) {}
    }

    // 2. Executa a requisição HTTP silenciosa
    final info = await UpdateService.verificarAtualizacao();
    if (info != null && info.containsKey("url")) {
      novaVersaoDisponivel = true;
      urlAtualizacao = info["url"].toString();
      tagNovaVersao = info["nova_versao"].toString();
      notifyListeners();
    }

    // 3. Atualiza o timestamp no arquivo config.json
    await _salvarDataChecagem();
  }

  Future<void> _salvarDataChecagem() async {
    _ultimaChecagemUpdateStr = DateTime.now().toIso8601String();
    final configMap = config.toJson();
    configMap['notion_api_key'] = notionApiKey;
    configMap['notion_database_id'] = notionDatabaseId;
    configMap['ultima_checagem_update'] = _ultimaChecagemUpdateStr;
    await storageService.writeJson(StorageService.configFile, configMap);
  }

  // Executa a busca forçada manual de atualizações (usado pelo botão nas configurações)
  Future<bool> forcarChecagemAtualizacao() async {
    // Sempre executa chamada de rede (ignora limite de 24h)
    final info = await UpdateService.verificarAtualizacao();
    await _salvarDataChecagem();

    if (info != null && info.containsKey("url")) {
      novaVersaoDisponivel = true;
      urlAtualizacao = info["url"].toString();
      tagNovaVersao = info["nova_versao"].toString();
      notifyListeners();
      return true;
    } else {
      novaVersaoDisponivel = false;
      urlAtualizacao = "";
      tagNovaVersao = "";
      notifyListeners();
      return false;
    }
  }

  // Executa o processo de download/navegador
  void executarAtualizacao() {
    if (urlAtualizacao.isNotEmpty) {
      UpdateService.iniciarAtualizacao(urlAtualizacao);
    }
  }

  // Lê e realiza o parsing manual do arquivo .env
  Future<Map<String, String>> _lerDotEnv() async {
    final Map<String, String> env = {};
    try {
      final file = File('.env');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            final key = parts[0].trim();
            final val = parts.sublist(1).join('=').trim().replaceAll('"', '').replaceAll("'", "");
            env[key] = val;
          }
        }
      }
    } catch (_) {}
    return env;
  }

  // Configura a conexão e inicializa o serviço do Notion
  void _configurarNotionService() {
    if (notionApiKey.isNotEmpty && notionDatabaseId.isNotEmpty) {
      notionService = NotionService(
        apiKey: notionApiKey,
        databaseId: notionDatabaseId,
        storageService: storageService,
      );

      notionService!.verificarConexao().then((conectado) {
        if (conectado) {
          labelStatus = "Notion conectado";
          textStatusColor = "#4CAF50";
          _sincronizarOfflineEmBackground();
        } else {
          labelStatus = "Notion offline - Modo local ativo";
          textStatusColor = "#FF9800";
        }
        notifyListeners();
      });
    } else {
      notionService = null;
      labelStatus = "Notion não configurado";
      textStatusColor = "#FF9800";
    }
  }

  // Tenta reconexão manual com o Notion
  Future<void> reconectarNotion() async {
    if (notionService == null) {
      _configurarNotionService();
      if (notionService == null) return;
    }

    labelStatus = "Conectando...";
    textStatusColor = "#2196F3"; // Azul
    notifyListeners();

    final sucesso = await notionService!.reconectar();
    if (sucesso) {
      labelStatus = "Conectado ao Notion!";
      textStatusColor = "#4CAF50";
      _sincronizarOfflineEmBackground();
    } else {
      labelStatus = "Conexão falhou - Mantendo offline";
      textStatusColor = "#F44336"; // Vermelho
    }
    notifyListeners();
  }

  // Salva novas credenciais informadas pelo usuário nas configurações do app
  Future<void> salvarCredenciaisNotion(String apiKey, String databaseId) async {
    notionApiKey = apiKey.trim();
    notionDatabaseId = databaseId.trim();

    final configMap = config.toJson();
    configMap['notion_api_key'] = notionApiKey;
    configMap['notion_database_id'] = notionDatabaseId;
    await storageService.writeJson(StorageService.configFile, configMap);

    _configurarNotionService();
    notifyListeners();
  }

  // --- Persistência do Contador ---

  Future<void> _carregarContadorHoje() async {
    try {
      final contadorData = await storageService.readJson(StorageService.contadorFile);
      if (contadorData is Map<String, dynamic>) {
        final dataHoje = DateTime.now().toIso8601String().substring(0, 10);
        if (contadorData['data'] == dataHoje) {
          pomodorosHoje = contadorData['count'] as int? ?? 0;
        }
      }
    } catch (_) {}
  }

  Future<void> _salvarContadorHoje() async {
    try {
      final dataHoje = DateTime.now().toIso8601String().substring(0, 10);
      await storageService.writeJson(StorageService.contadorFile, {
        "data": dataHoje,
        "count": pomodorosHoje,
      });
    } catch (_) {}
  }

  // --- Controles de Operação do Cronômetro ---

  void iniciar(String tarefa, String categoria) {
    if (rodando) return;
    tarefaAtual = tarefa.trim();
    categoriaAtual = categoria;

    if (tarefaAtual.isEmpty) {
      labelStatus = "Digite uma tarefa!";
      textStatusColor = "#F44336";
      notifyListeners();
      return;
    }

    if (tarefaAtual.length < 3) {
      labelStatus = "Tarefa muito curta (mín. 3 chars)";
      textStatusColor = "#F44336";
      notifyListeners();
      return;
    }

    rodando = true;
    pausado = false;
    tipoDescanso = null;
    tempoInicio = DateTime.now();
    
    // Define o momento exato em que a sessão deve terminar
    final totalSegundos = config.tempoTrabalho * 60;
    tempoFim = tempoInicio!.add(Duration(seconds: totalSegundos));
    tempoRestante = totalSegundos;
    
    labelStatus = "Focado...";
    textStatusColor = "#FFD700"; // Amarelo

    // Adiciona o termo ao histórico de autocomplete
    _adicionarAoHistorico(tarefaAtual);

    // Agenda o alarme no Android para o momento exato
    if (Platform.isAndroid) {
      notificationService.cancelarNotificacoes().then((_) {
        notificationService.agendarNotificacaoFimFoco(
          999, // Unificado com o ID da notificação final
          "🎉 Pomodoro Concluído!",
          "Tarefa: $tarefaAtual\nTempo: ${config.tempoTrabalho} min",
          tempoFim!,
          comSom: config.somAlarmeAtivado,
          comVibracao: config.vibrarAoFinalizar,
        );
        // Exibe o cronômetro nativo persistente na barra de status
        notificationService.exibirNotificacaoCronometro(
          "🍅 Foco em Andamento",
          tarefaAtual,
          tempoFim!,
        );
      });
    }

    _iniciarTicker();
    notifyListeners();
  }

  // Atalho usado pelo servidor de API local HTTP
  void iniciarViaApi({String? tarefa, String? categoria}) {
    final t = tarefa ?? tarefaAtual;
    final c = categoria ?? (config.categorias.isNotEmpty ? config.categorias[0] : "Outros");
    iniciar(t, c);
  }

  void pausarRetomar() {
    if (!rodando) return;
    if (pausado) {
      // Retomando: recalcula tempoFim com base nos segundos que faltavam
      pausado = false;
      tempoFim = DateTime.now().add(Duration(seconds: tempoRestante));
      
      if (Platform.isAndroid) {
        notificationService.cancelarNotificacoes().then((_) {
          if (modoDescanso) {
            notificationService.agendarNotificacao(
              2,
              "✅ Descanso Concluído!",
              "Pronto para outro Pomodoro?",
              tempoFim!,
            );
          } else {
            notificationService.agendarNotificacaoFimFoco(
              999,
              "🎉 Pomodoro Concluído!",
              "Tarefa: $tarefaAtual\nTempo: ${config.tempoTrabalho} min",
              tempoFim!,
              comSom: config.somAlarmeAtivado,
              comVibracao: config.vibrarAoFinalizar,
            );
          }
          // Retoma o cronômetro persistente na barra de status
          notificationService.exibirNotificacaoCronometro(
            modoDescanso ? "☕ Descanso em Andamento" : "🍅 Foco em Andamento",
            tarefaAtual.isEmpty ? "Aproveite para relaxar!" : tarefaAtual,
            tempoFim!,
          );
        });
      }
      
      labelStatus = modoDescanso ? "Descansando..." : "Focado...";
      textStatusColor = modoDescanso ? "#FF9800" : "#FFD700";
    } else {
      // Pausando: cancela a notificação agendada e o cronômetro persistente
      pausado = true;
      if (Platform.isAndroid) {
        notificationService.cancelarNotificacoes();
        notificationService.removerNotificacaoCronometro();
      }
      labelStatus = "Pausado";
      textStatusColor = "#FFA500";
    }
    notifyListeners();
  }

  void resetar() {
    _ticker?.cancel();
    if (Platform.isAndroid) {
      notificationService.cancelarNotificacoes();
      notificationService.removerNotificacaoCronometro();
    }
    tempoRestante = config.tempoTrabalho * 60;
    rodando = false;
    pausado = false;
    tempoInicio = null;
    tempoFim = null;
    modoDescanso = false;
    tipoDescanso = null;
    labelStatus = "Pronto para começar";
    textStatusColor = "#4CAF50";
    labelDecorrido = "";
    progresso = 0.0;
    sessaoEmFinalizacao = false;
    tarefaAtual = ""; // Limpa a descrição da tarefa atual
    notifyListeners();
  }

  void iniciarDescanso(bool longo) {
    _ticker?.cancel();
    modoDescanso = true;
    tipoDescanso = longo ? "longo" : "curto";
    
    final minutosDescanso = longo ? config.tempoDescansoLongo : config.tempoDescansoCurto;
    final totalSegundos = minutosDescanso * 60;
    tempoRestante = totalSegundos;
    
    rodando = true;
    pausado = false;
    tempoInicio = DateTime.now();
    tempoFim = tempoInicio!.add(Duration(seconds: totalSegundos));
    progresso = 0.0;

    // Agenda o alarme do descanso no Android para o momento exato
    if (Platform.isAndroid) {
      notificationService.cancelarNotificacoes().then((_) {
        notificationService.agendarNotificacao(
          2,
          "✅ Descanso Concluído!",
          "Pronto para outro Pomodoro?",
          tempoFim!,
        );
        // Exibe o cronômetro nativo do descanso
        notificationService.exibirNotificacaoCronometro(
          longo ? "☕ Descanso Longo em Andamento" : "☕ Descanso em Andamento",
          "Aproveite para relaxar!",
          tempoFim!,
        );
      });
    }

    labelStatus = longo ? "Descanso Longo..." : "Descansando...";
    textStatusColor = "#FF9800";
    labelDecorrido = "";

    _iniciarTicker();
    notifyListeners();
  }

  void pularDescanso() {
    resetar();
  }

  void _iniciarTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
  }

  // Processo de loop de 1 segundo
  void _tick() {
    if (pausado || !rodando || tempoFim == null) return;

    final agora = DateTime.now();
    if (agora.isBefore(tempoFim!)) {
      // Diferença em segundos baseada no relógio do sistema (à prova de suspensão do sistema)
      tempoRestante = tempoFim!.difference(agora).inSeconds;
      _atualizarProgresso();

      if (!modoDescanso && tempoInicio != null) {
        final totalDecorrido = agora.difference(tempoInicio!).inSeconds;
        final minutos = totalDecorrido ~/ 60;
        final segundos = totalDecorrido % 60;
        labelDecorrido = "⏱ Focado há ${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";
      }
      notifyListeners();
    } else {
      _ticker?.cancel();
      tempoRestante = 0;
      progresso = 1.0;
      notifyListeners();
      
      if (modoDescanso) {
        _finalizarDescanso();
      } else {
        _finalizarSessao();
      }
    }
  }

  void _atualizarProgresso() {
    int total = config.tempoTrabalho * 60;
    if (modoDescanso) {
      total = (tipoDescanso == "longo" ? config.tempoDescansoLongo : config.tempoDescansoCurto) * 60;
    }
    if (total == 0) {
      progresso = 1.0;
    } else {
      final decorrido = total - tempoRestante;
      progresso = (decorrido / total).clamp(0.0, 1.0);
    }
  }

  // --- Conclusão de Sessão ---

  void _finalizarSessao() {
    if (sessaoEmFinalizacao) return;
    sessaoEmFinalizacao = true;
    rodando = false;
    if (tempoFim == null) {
      tempoFim = DateTime.now();
    }
    pomodorosCompletados++;
    pomodorosHoje++;
    _salvarContadorHoje();

    if (Platform.isAndroid) {
      notificationService.removerNotificacaoCronometro();
      notificationService.cancelarNotificacoes();
    }

    labelStatus = "Enviando...";
    textStatusColor = "#2196F3";
    labelDecorrido = "";
    notifyListeners();

    // 1. Prioridade Máxima: Registra a sessão no Notion imediatamente
    _registrarNoNotion(tarefaAtual, tempoInicio!, tempoFim!, categoriaAtual, true);

    // 2. Toca som de alarme com proteção de erros
    if (config.somAlarmeAtivado) {
      try {
        notificationService.tocarAlarme();
      } catch (_) {}
    }

    // Verifica se o aplicativo está ativo (aberto na tela)
    final isInForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    // 3. Dispara a notificação de forma isolada e segura (APENAS se estiver minimizado/ausente)
    if (!isInForeground) {
      try {
        if (Platform.isAndroid) {
          notificationService.notificarFimFoco(
            "🎉 Pomodoro Concluído!",
            "Tarefa: $tarefaAtual\nTempo: ${config.tempoTrabalho} min",
            comSom: config.somAlarmeAtivado,
            comVibracao: config.vibrarAoFinalizar,
          );
        } else {
          notificationService.notificar("🎉 Pomodoro Concluído!", "Tarefa: $tarefaAtual\nTempo: ${config.tempoTrabalho} min");
        }
      } catch (_) {}
    }

    // Força a janela do Windows a piscar ou vir para frente
    if (Platform.isWindows) {
      try {
        windowManager.show();
        windowManager.focus();
      } catch (_) {}
    }

    // 4. Abre o popup na UI de forma isolada (capturando falhas caso o app esteja minimizado)
    if (onSessionFinished != null) {
      try {
        onSessionFinished!();
      } catch (_) {}
    }
  }

  // Encerramento antecipado
  void finalizarSessaoManualmente() {
    if (sessaoEmFinalizacao || !rodando || modoDescanso) return;
    _ticker?.cancel();
    sessaoEmFinalizacao = true;
    rodando = false;
    tempoFim = DateTime.now();

    if (Platform.isAndroid) {
      notificationService.removerNotificacaoCronometro();
    }

    labelStatus = "Encerrando sessão...";
    textStatusColor = "#2196F3";
    labelDecorrido = "";
    notifyListeners();

    _registrarNoNotion("[Encerrado] $tarefaAtual", tempoInicio!, tempoFim!, categoriaAtual, false);
  }

  void _finalizarDescanso() {
    rodando = false;
    labelStatus = "Descanso concluído!";
    textStatusColor = "#4CAF50";
    progresso = 0.0;
    notifyListeners();

    if (Platform.isAndroid) {
      notificationService.removerNotificacaoCronometro();
    }

    if (config.somAlarmeAtivado) {
      try {
        notificationService.tocarAlarme();
      } catch (_) {}
    }

    try {
      notificationService.notificar("✅ Descanso Concluído!", "Pronto para outro Pomodoro?");
    } catch (_) {}

    if (Platform.isWindows) {
      try {
        windowManager.show();
        windowManager.focus();
      } catch (_) {}
    }

    if (onBreakFinished != null) {
      try {
        onBreakFinished!();
      } catch (_) {}
    }

    resetar();
  }

  // Comunicação assíncrona com o Notion
  Future<void> _registrarNoNotion(
    String tarefa,
    DateTime inicio,
    DateTime fim,
    String categoria,
    bool pomodoroCompleto,
  ) async {
    if (notionService == null) {
      labelStatus = "⚠️ Sem Notion - Salvo localmente";
      textStatusColor = "#FF9800";
      if (!pomodoroCompleto) {
        resetar();
      } else {
        sessaoEmFinalizacao = false;
        notifyListeners();
      }
      return;
    }

    final sucesso = await notionService!.registrarSessao(
      intervalo: tarefa,
      inicio: inicio,
      fim: fim,
      tecnologia: categoria,
      campoRelacao: campoRelacaoSelecionado,
      idRelacao: idRelacaoSelecionado,
    );

    if (sucesso) {
      labelStatus = pomodoroCompleto ? "✓ Registrado no Notion!" : "✓ Sessão encerrada e registrada!";
      textStatusColor = "#4CAF50";
      if (!pomodoroCompleto) {
        await Future.delayed(const Duration(seconds: 2));
        resetar();
      } else {
        sessaoEmFinalizacao = false;
        notifyListeners();
      }
    } else {
      labelStatus = notionService!.connected
          ? "✗ Erro no envio - Salvo localmente"
          : "⚠️ Sem conexão - Salvo localmente";
      textStatusColor = "#FF9800";
      if (!pomodoroCompleto) {
        await Future.delayed(const Duration(seconds: 2));
        resetar();
      } else {
        sessaoEmFinalizacao = false;
        notifyListeners();
      }
    }
  }

  // --- Autocomplete Inteligente ---

  Future<void> _adicionarAoHistorico(String tarefa) async {
    final t = tarefa.trim();
    if (t.isEmpty) return;

    if (historicoTarefas.contains(t)) {
      historicoTarefas.remove(t);
    }
    historicoTarefas.insert(0, t);

    // Limita o cache às últimas 20 tarefas
    if (historicoTarefas.length > 20) {
      historicoTarefas = historicoTarefas.sublist(0, 20);
    }

    await storageService.writeJson(StorageService.historicoFile, historicoTarefas);
    notifyListeners();
  }

  List<String> obterSugestoesAutocomplete(String prefixo) {
    final p = prefixo.trim().toLowerCase();
    if (p.isEmpty) {
      return historicoTarefas.take(5).toList();
    }
    return historicoTarefas.where((t) => t.toLowerCase().startsWith(p)).take(5).toList();
  }

  Future<void> limparHistorico() async {
    historicoTarefas.clear();
    await storageService.writeJson(StorageService.historicoFile, historicoTarefas);
    notifyListeners();
  }

  bool precisaLongBreak() {
    return pomodorosCompletados > 0 && pomodorosCompletados % config.pomodorosAteLongBreak == 0;
  }

  void _sincronizarOfflineEmBackground() {
    if (notionService == null || !notionService!.connected) return;
    notionService!.sincronizarSessoesOffline().then((qtd) {
      if (qtd > 0) {
        labelStatus = "✓ Sincronizadas $qtd sessões offline!";
        textStatusColor = "#4CAF50";
        notifyListeners();
      }
    });
  }

  // Formatação do tempo restante (MM:SS)
  String obterTempoFormatado() {
    final minutos = tempoRestante ~/ 60;
    final segundos = tempoRestante % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  // Atualização e gravação de novas durações do Pomodoro
  Future<void> atualizarConfig(PomodoroConfig novaConfig) async {
    if (rodando) {
      resetar();
      labelStatus = "⚙️ Timer resetado para aplicar configurações";
      textStatusColor = "#FFA500";
    }

    config = novaConfig;
    tempoRestante = config.tempoTrabalho * 60;

    final configMap = config.toJson();
    configMap['notion_api_key'] = notionApiKey;
    configMap['notion_database_id'] = notionDatabaseId;
    await storageService.writeJson(StorageService.configFile, configMap);

    notifyListeners();
  }

  // Acionado quando o aplicativo é minimizado ou a tela é desligada
  void mostrarNotificacaoMinimizada() {
    if (Platform.isAndroid && tempoFim != null && rodando) {
      final horaFimStr = "${tempoFim!.hour.toString().padLeft(2, '0')}:${tempoFim!.minute.toString().padLeft(2, '0')}";
      notificationService.exibirNotificacaoCronometro(
        modoDescanso ? "☕ Descanso em Andamento" : "🍅 Foco em Andamento",
        "Término às $horaFimStr • ${modoDescanso ? 'Aproveite para relaxar!' : tarefaAtual}",
        tempoFim!,
      );
    }
  }

  // Acionado quando o aplicativo retorna para o primeiro plano
  void ocultarNotificacaoMinimizada() {
    if (Platform.isAndroid) {
      notificationService.removerNotificacaoCronometro();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

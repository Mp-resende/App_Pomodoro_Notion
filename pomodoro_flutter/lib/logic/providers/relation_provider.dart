import 'package:flutter/foundation.dart';
import '../../core/services/notion_service.dart';
import 'timer_provider.dart';

class RelationProvider with ChangeNotifier {
  final TimerProvider timerProvider;
  Map<String, dynamic> camposRelacao = {};
  bool carregando = false;
  bool tentouCarregar = false;

  RelationProvider({required this.timerProvider}) {
    // Assina o TimerProvider para tentar recarregar as relações assim que houver conexão com o Notion
    timerProvider.addListener(_onTimerProviderChange);
  }

  void _onTimerProviderChange() {
    if (timerProvider.notionService != null &&
        timerProvider.notionService!.connected &&
        camposRelacao.isEmpty &&
        !carregando &&
        !tentouCarregar) {
      carregarCamposRelacao();
    }
  }

  // Carrega em background todos os campos de relação
  Future<void> carregarCamposRelacao() async {
    final service = timerProvider.notionService;
    if (service == null || !service.connected) return;

    carregando = true;
    tentouCarregar = true;
    notifyListeners();

    try {
      final campos = await service.detectarCamposRelacao();
      camposRelacao = campos;

      // Configura os valores padrões iniciais no TimerProvider se houver campos detectados
      if (camposRelacao.isNotEmpty && timerProvider.campoRelacaoSelecionado == null) {
        final primeiroCampo = camposRelacao.keys.first;
        timerProvider.campoRelacaoSelecionado = primeiroCampo;

        final opcoes = camposRelacao[primeiroCampo]['opcoes'] as List<dynamic>? ?? [];
        if (opcoes.isNotEmpty) {
          timerProvider.idRelacaoSelecionado = opcoes.first['id']?.toString();
        }
      }
    } catch (_) {}

    carregando = false;
    notifyListeners();
  }

  // Altera o campo de relação e reseta a seleção de valor padrão
  void selecionarCampo(String campo) {
    if (!camposRelacao.containsKey(campo)) return;

    timerProvider.campoRelacaoSelecionado = campo;
    final opcoes = camposRelacao[campo]['opcoes'] as List<dynamic>? ?? [];
    if (opcoes.isNotEmpty) {
      timerProvider.idRelacaoSelecionado = opcoes.first['id']?.toString();
    } else {
      timerProvider.idRelacaoSelecionado = null;
    }

    notifyListeners();
    timerProvider.notifyListeners();
  }

  // Seleciona um valor específico dentro do campo ativo (ex: título de uma tarefa relacionada)
  void selecionarValor(String valorTitulo) {
    final campo = timerProvider.campoRelacaoSelecionado;
    if (campo == null || !camposRelacao.containsKey(campo)) return;

    final opcoes = camposRelacao[campo]['opcoes'] as List<dynamic>? ?? [];
    for (final opcao in opcoes) {
      if (opcao['title'] == valorTitulo) {
        timerProvider.idRelacaoSelecionado = opcao['id']?.toString();
        break;
      }
    }

    notifyListeners();
    timerProvider.notifyListeners();
  }

  // Retorna a lista de títulos textuais disponíveis para preencher a combobox
  List<String> obterOpcoesTitulos(String campo) {
    if (!camposRelacao.containsKey(campo)) return [];
    final opcoes = camposRelacao[campo]['opcoes'] as List<dynamic>? ?? [];
    return opcoes.map((e) => e['title']?.toString() ?? '').where((t) => t.isNotEmpty).toList();
  }

  // Cria uma nova opção na base do Notion correspondente ao campo atual e a seleciona
  Future<bool> criarNovaOpcao(String titulo) async {
    final campo = timerProvider.campoRelacaoSelecionado;
    final service = timerProvider.notionService;
    if (campo == null || service == null || !service.connected || !camposRelacao.containsKey(campo)) return false;

    carregando = true;
    notifyListeners();

    final relatedDbId = camposRelacao[campo]['database_id'] as String;
    final novoId = await service.criarOpcaoRelacao(relatedDbId, titulo);

    if (novoId != null) {
      // Recarrega a lista de opções silenciosamente do Notion
      final novasOpcoes = await service.consultarOpcoesRelacao(relatedDbId);
      camposRelacao[campo]['opcoes'] = novasOpcoes;
      
      // Seleciona a opção recém-criada
      timerProvider.idRelacaoSelecionado = novoId;
      
      carregando = false;
      notifyListeners();
      timerProvider.notifyListeners();
      return true;
    }

    carregando = false;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    timerProvider.removeListener(_onTimerProviderChange);
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/relation_provider.dart';
import '../../logic/providers/timer_provider.dart';

class RelationSelector extends StatelessWidget {
  const RelationSelector({Key? key}) : super(key: key);

  void _abrirModalBuscaECriacao(BuildContext context, RelationProvider rp, List<String> opcoesIniciais, String? selecionado) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return _RelationSearchModal(
          opcoesIniciais: opcoesIniciais,
          relationProvider: rp,
          selecionadoInicial: selecionado,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final relationProvider = Provider.of<RelationProvider>(context);
    final timerProvider = Provider.of<TimerProvider>(context);

    // Oculta a interface de relações enquanto o timer estiver rodando ou pausado (foco ativo)
    if (timerProvider.rodando) {
      return const SizedBox.shrink();
    }

    // Se estiver buscando os dados nas databases secundárias do Notion, exibe um spinner sutil
    if (relationProvider.carregando) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Carregando relações do Notion...",
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
    }

    final campos = relationProvider.camposRelacao;
    if (campos.isEmpty) {
      return const SizedBox.shrink(); // Oculta o widget inteiro caso não existam relações mapeadas
    }

    final campoSelecionado = timerProvider.campoRelacaoSelecionado;
    final valorSelecionado = timerProvider.idRelacaoSelecionado;

    // Resgata o título (plain text) correspondente ao ID selecionado para preencher a caixa
    String? tituloSelecionado;
    if (campoSelecionado != null && valorSelecionado != null && campos.containsKey(campoSelecionado)) {
      final opcoes = campos[campoSelecionado]['opcoes'] as List<dynamic>? ?? [];
      for (final op in opcoes) {
        if (op['id'] == valorSelecionado) {
          tituloSelecionado = op['title'] as String?;
          break;
        }
      }
    }

    final listaCampos = campos.keys.toList();
    final listaOpcoesTitulos = campoSelecionado != null
        ? relationProvider.obterOpcoesTitulos(campoSelecionado)
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.link_rounded,
              color: Colors.cyanAccent,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              "Relacionar no Notion:",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                relationProvider.carregarCamposRelacao();
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Tooltip(
                  message: "Sincronizar relações",
                  child: Icon(
                    Icons.sync_rounded,
                    color: Colors.cyanAccent.withOpacity(0.7),
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Dropdown 1: Selecionar o Campo de Relação da Tabela
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.035),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: campoSelecionado != null && listaCampos.contains(campoSelecionado)
                        ? campoSelecionado
                        : null,
                    hint: Text("Coluna", style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12.5)),
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.white.withOpacity(0.5)),
                    items: listaCampos.map((campo) {
                      return DropdownMenuItem<String>(
                        value: campo,
                        child: Text(campo),
                      );
                    }).toList(),
                    onChanged: timerProvider.rodando
                        ? null // Bloqueia alterações se o timer estiver rodando
                        : (val) {
                            if (val != null) {
                              relationProvider.selecionarCampo(val);
                            }
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Dropdown 2: Selecionar a linha / registro associado (Botão que abre modal inteligente)
            Expanded(
              child: GestureDetector(
                onTap: timerProvider.rodando ? null : () {
                  if (campoSelecionado != null) {
                    _abrirModalBuscaECriacao(context, relationProvider, listaOpcoesTitulos, tituloSelecionado);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 48, // Alinhado com a altura do outro dropdown
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tituloSelecionado ?? "Buscar ou Criar...",
                          style: TextStyle(
                            color: tituloSelecionado != null ? Colors.white : Colors.white.withOpacity(0.4),
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5), size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Widget do Modal Inferior (Bottom Sheet) com Busca e Botão de Criação
class _RelationSearchModal extends StatefulWidget {
  final List<String> opcoesIniciais;
  final RelationProvider relationProvider;
  final String? selecionadoInicial;

  const _RelationSearchModal({
    required this.opcoesIniciais,
    required this.relationProvider,
    this.selecionadoInicial,
  });

  @override
  State<_RelationSearchModal> createState() => _RelationSearchModalState();
}

class _RelationSearchModalState extends State<_RelationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _listaFiltrada = [];
  bool _criando = false;

  @override
  void initState() {
    super.initState();
    _listaFiltrada = List.from(widget.opcoesIniciais);
  }

  void _filtrar(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _listaFiltrada = List.from(widget.opcoesIniciais);
      } else {
        _listaFiltrada = widget.opcoesIniciais
            .where((titulo) => titulo.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _criarNovo() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _criando = true);
    final sucesso = await widget.relationProvider.criarNovaOpcao(query);
    setState(() => _criando = false);

    if (sucesso && mounted) {
      Navigator.pop(context); // Fecha o modal após criar
    } else if (mounted) {
      // Opcional: mostrar snackbar de erro
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao criar. Tente novamente."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final telaAltura = MediaQuery.of(context).size.height;
    final tecladoAltura = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: telaAltura * 0.7 + tecladoAltura,
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: tecladoAltura + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Selecionar ou Criar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Barra de Pesquisa / Criação
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Buscar ou digitar novo nome...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: _filtrar,
                ),
              ),
              const SizedBox(width: 10),
              // Mostrar botão Criar se há texto e não há correspondência exata
              if (_searchController.text.trim().isNotEmpty && !_listaFiltrada.any((e) => e.toLowerCase() == _searchController.text.trim().toLowerCase()))
                ElevatedButton.icon(
                  onPressed: _criando ? null : _criarNovo,
                  icon: _criando 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: const Text("Criar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Lista de resultados
          Expanded(
            child: _listaFiltrada.isEmpty
                ? Center(child: Text("Nenhuma opção encontrada.\nDigite para criar uma nova!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5))))
                : ListView.builder(
                    itemCount: _listaFiltrada.length,
                    itemBuilder: (context, index) {
                      final titulo = _listaFiltrada[index];
                      final isSelected = titulo == widget.selecionadoInicial;
                      return ListTile(
                        title: Text(titulo, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        tileColor: isSelected ? Colors.cyanAccent.withOpacity(0.05) : Colors.transparent,
                        onTap: () {
                          widget.relationProvider.selecionarValor(titulo);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


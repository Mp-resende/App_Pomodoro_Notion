import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/timer_provider.dart';

class AutocompleteInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  const AutocompleteInput({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
  }) : super(key: key);

  @override
  State<AutocompleteInput> createState() => _AutocompleteInputState();
}

class _AutocompleteInputState extends State<AutocompleteInput> {
  List<String> _sugestoes = [];
  bool _mostrarSugestoes = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  // Monitora alterações textuais para recalcular sugestões
  void _onTextChanged() {
    if (!widget.focusNode.hasFocus) return;
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final texto = widget.controller.text;

    setState(() {
      _sugestoes = timerProvider.obterSugestoesAutocomplete(texto);
      _mostrarSugestoes = _sugestoes.isNotEmpty;
    });
  }

  // Oculta sugestões quando perde foco
  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      // Pequeno delay para garantir o clique na lista antes do sumiço do widget
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() {
            _mostrarSugestoes = false;
          });
        }
      });
    } else {
      _onTextChanged();
    }
  }

  // Alterna visibilidade do dropdown de histórico ao clicar no botão ▼
  void _toggleAutocomplete() {
    if (!widget.enabled) return;
    if (_mostrarSugestoes) {
      setState(() {
        _mostrarSugestoes = false;
      });
    } else {
      widget.focusNode.requestFocus();
      final timerProvider = Provider.of<TimerProvider>(context, listen: false);
      setState(() {
        _sugestoes = timerProvider.obterSugestoesAutocomplete(widget.controller.text);
        if (_sugestoes.isEmpty) {
          _sugestoes = timerProvider.historicoTarefas.take(5).toList();
        }
        _mostrarSugestoes = _sugestoes.isNotEmpty;
      });
    }
  }

  // Preenche o campo com a sugestão selecionada
  void _selecionarSugestao(String tarefa) {
    widget.controller.text = tarefa;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: tarefa.length),
    );
    setState(() {
      _mostrarSugestoes = false;
    });
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.cyanAccent.withOpacity(0.5);
    final Color inactiveColor = Colors.white.withOpacity(0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.035),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.focusNode.hasFocus ? activeColor : inactiveColor,
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "O que vai codar hoje?",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botão ▼ de histórico
            Material(
              color: Colors.white.withOpacity(0.035),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: widget.enabled ? _toggleAutocomplete : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _mostrarSugestoes ? activeColor : inactiveColor,
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: widget.enabled ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.15),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Painel flutuante interno de autocomplete
        if (_mostrarSugestoes)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sugestoes.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.white.withOpacity(0.05),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final sugestao = _sugestoes[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selecionarSugestao(sugestao),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          sugestao,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/relation_provider.dart';
import '../../logic/providers/timer_provider.dart';

class RelationSelector extends StatelessWidget {
  const RelationSelector({Key? key}) : super(key: key);

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
            // Dropdown 2: Selecionar a linha / registro associado
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
                    value: tituloSelecionado != null && listaOpcoesTitulos.contains(tituloSelecionado)
                        ? tituloSelecionado
                        : null,
                    hint: Text("Item Vinculado", style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12.5)),
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.white.withOpacity(0.5)),
                    items: listaOpcoesTitulos.map((titulo) {
                      return DropdownMenuItem<String>(
                        value: titulo,
                        child: Text(
                          titulo,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: timerProvider.rodando
                        ? null // Bloqueia se o timer estiver ativo
                        : (val) {
                            if (val != null) {
                              relationProvider.selecionarValor(val);
                            }
                          },
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

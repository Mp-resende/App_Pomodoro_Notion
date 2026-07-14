import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/pomodoro_config.dart';
import '../../../logic/providers/timer_provider.dart';
import 'package:pomodoro_notion/core/services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _trabalhoController;
  late TextEditingController _descansoCurtoController;
  late TextEditingController _descansoLongoController;
  late TextEditingController _cicloLBreakController;
  late TextEditingController _novaCatController;
  late TextEditingController _apiKeyController;
  late TextEditingController _dbIdController;

  late bool _somAlarme;
  late bool _notifSistema;
  late List<String> _categorias;
  bool _iniciado = false;
  bool _buscandoUpdate = false;

  @override
  void initState() {
    super.initState();
    // Inicializa controllers vazios — serão preenchidos em didChangeDependencies
    _trabalhoController = TextEditingController();
    _descansoCurtoController = TextEditingController();
    _descansoLongoController = TextEditingController();
    _cicloLBreakController = TextEditingController();
    _novaCatController = TextEditingController();
    _apiKeyController = TextEditingController();
    _dbIdController = TextEditingController();
    _somAlarme = true;
    _notifSistema = true;
    _categorias = [];
  }

  // didChangeDependencies é o local correto para acessar Provider/InheritedWidget
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return; // Executa apenas uma vez
    _iniciado = true;

    final timerProvider = Provider.of<TimerProvider>(context, listen: false);

    _trabalhoController.text = timerProvider.config.tempoTrabalho.toString();
    _descansoCurtoController.text = timerProvider.config.tempoDescansoCurto.toString();
    _descansoLongoController.text = timerProvider.config.tempoDescansoLongo.toString();
    _cicloLBreakController.text = timerProvider.config.pomodorosAteLongBreak.toString();

    _apiKeyController.text = timerProvider.notionApiKey;
    _dbIdController.text = timerProvider.notionDatabaseId;

    _somAlarme = timerProvider.config.somAlarmeAtivado;
    _notifSistema = timerProvider.config.notificacoesSistema;
    _categorias = List<String>.from(timerProvider.config.categorias);
  }

  // Adiciona categoria na lista local temporária
  void _adicionarCategoria() {
    final nova = _novaCatController.text.trim();
    if (nova.isEmpty) return;
    if (_categorias.contains(nova)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("A categoria '$nova' já existe!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      _categorias.add(nova);
      _novaCatController.clear();
    });
  }

  // Remove categoria da lista local temporária
  void _removerCategoria(int index) {
    if (_categorias.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("O aplicativo precisa de pelo menos uma categoria ativa!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      _categorias.removeAt(index);
    });
  }

  // Grava as novas configurações no Provider e persiste no JSON
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final timerProvider = Provider.of<TimerProvider>(context, listen: false);

    final novaConfig = PomodoroConfig(
      tempoTrabalho: int.parse(_trabalhoController.text),
      tempoDescansoCurto: int.parse(_descansoCurtoController.text),
      tempoDescansoLongo: int.parse(_descansoLongoController.text),
      pomodorosAteLongBreak: int.parse(_cicloLBreakController.text),
      somAlarmeAtivado: _somAlarme,
      notificacoesSistema: _notifSistema,
      categorias: _categorias,
    );

    // Persiste as chaves do Notion
    await timerProvider.salvarCredenciaisNotion(
      _apiKeyController.text,
      _dbIdController.text,
    );

    // Grava e recarrega os tempos de sessão no cronômetro
    await timerProvider.atualizarConfig(novaConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Configurações salvas e aplicadas!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("⚙️ Configurações", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              // --- SEÇÃO: TEMPOS ---
              _buildSectionTitle("⏱ Tempos (Minutos)"),
              const SizedBox(height: 12),
              _buildTextFormField(
                controller: _trabalhoController,
                label: "Tempo de Foco (1 - 480 min)",
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 480) return "Valor de 1 a 480";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextFormField(
                controller: _descansoCurtoController,
                label: "Descanso Curto (1 - 60 min)",
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 60) return "Valor de 1 a 60";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextFormField(
                controller: _descansoLongoController,
                label: "Descanso Longo (1 - 120 min)",
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 120) return "Valor de 1 a 120";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextFormField(
                controller: _cicloLBreakController,
                label: "Ciclo (Pomodoros até descanso longo) (1 - 10)",
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 10) return "Valor de 1 a 10";
                  return null;
                },
              ),

              const SizedBox(height: 24),
              // --- SEÇÃO: OPÇÕES DE SISTEMA ---
              _buildSectionTitle("🔔 Sons & Notificações"),
              SwitchListTile(
                value: _somAlarme,
                title: const Text("Ativar Som do Alarme", style: TextStyle(color: Colors.white70, fontSize: 13)),
                activeColor: Colors.cyanAccent,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _somAlarme = val),
              ),
              SwitchListTile(
                value: _notifSistema,
                title: const Text("Ativar Notificações do Sistema", style: TextStyle(color: Colors.white70, fontSize: 13)),
                activeColor: Colors.cyanAccent,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _notifSistema = val),
              ),

              const SizedBox(height: 24),
              // --- SEÇÃO: CATEGORIAS ---
              _buildSectionTitle("📂 Gerenciar Categorias"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _novaCatController,
                      label: "Nova tecnologia...",
                      validator: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _adicionarCategoria,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Exibe chips das categorias com botão X para apagar
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_categorias.length, (index) {
                  final cat = _categorias[index];
                  return Chip(
                    backgroundColor: Colors.white.withOpacity(0.035),
                    side: BorderSide(color: Colors.white.withOpacity(0.07)),
                    label: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                    onDeleted: () => _removerCategoria(index),
                  );
                }),
              ),

              const SizedBox(height: 24),
              // --- SEÇÃO: INFORMAÇÕES E ATUALIZAÇÕES ---
              _buildSectionTitle("⚙️ Aplicativo"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.015),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Versão Instalada",
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "v${UpdateService.versaoAtual}",
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _buscandoUpdate
                          ? null
                          : () async {
                              setState(() => _buscandoUpdate = true);
                              final timerProvider = Provider.of<TimerProvider>(context, listen: false);
                              final encontrou = await timerProvider.forcarChecagemAtualizacao();
                              if (mounted) {
                                setState(() => _buscandoUpdate = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(encontrou
                                        ? "Nova versão disponível! Verifique a tela inicial."
                                        : "Você já possui a versão mais recente instalada."),
                                    backgroundColor: encontrou ? Colors.green : Colors.blueGrey,
                                  ),
                                );
                              }
                            },
                      icon: _buscandoUpdate
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.cyanAccent),
                            )
                          : const Icon(Icons.cloud_download_rounded, size: 16),
                      label: Text(
                        _buscandoUpdate ? "Buscando..." : "Buscar atualizações",
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: Colors.cyanAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // --- SEÇÃO: NOTION ---
              _buildSectionTitle("🔗 Credenciais do Notion"),
              const SizedBox(height: 12),
              _buildTextFormField(
                controller: _apiKeyController,
                label: "Token de Integração Interna (Internal Token)",
                obscureText: true,
                validator: null,
              ),
              const SizedBox(height: 12),
              _buildTextFormField(
                controller: _dbIdController,
                label: "ID da Base de Dados (Database ID)",
                validator: null,
              ),

              const SizedBox(height: 38),
              // --- BOTÕES DE SALVAR/CANCELAR ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Salvar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.04),
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withOpacity(0.06)),
                        ),
                      ),
                      child: const Text("Cancelar", style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        keyboardType: validator != null ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          isDense: true,
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 9.5),
        ),
      ),
    );
  }
}

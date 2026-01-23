# 📐 ARQUITETURA E ESTRUTURA DO PROJETO

## 📁 Estrutura de Arquivos

```
App_Pomodoro_Notion/
│
├── 🐍 CÓDIGO PRINCIPAL
│   ├── main.py                 # Aplicação principal (GUI + lógica)
│   └── tests.py                # Testes e validações
│
├── 📚 DOCUMENTAÇÃO
│   ├── README.md               # Guia completo
│   ├── QUICK_START.md          # Início rápido (5 min)
│   ├── NOTION_SETUP.md         # Configuração detalhada do Notion
│   ├── ARCHITECTURE.md         # Este arquivo
│   └── EXAMPLES.md             # Exemplos de uso
│
├── ⚙️ CONFIGURAÇÃO
│   ├── requirements.txt        # Dependências Python
│   ├── .env.example            # Exemplo de variáveis de ambiente
│   ├── .gitignore              # Arquivos ignorados no Git
│   └── setup.sh                # Script de instalação automática
│
└── 📋 INFORMAÇÃO
    └── Este arquivo            # Você está aqui!
```

---

## 🏗️ Arquitetura da Aplicação

### Diagrama de Camadas

```
┌─────────────────────────────────────────────────────┐
│           INTERFACE GRÁFICA (GUI)                   │
│   (customtkinter - Dark Mode - 500x650px)           │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │  Timer Display    │  24:59 Entrada de Texto │  │
│  │  (72pt font)      │  (Task description)     │  │
│  ├──────────────────────────────────────────────┤  │
│  │ ComboBox Categoria │ Label de Status        │  │
│  │ (Python, C#, SQL)  │ (Focado... / Sucesso) │  │
│  ├──────────────────────────────────────────────┤  │
│  │    [Iniciar] [Resetar]  (Botões)            │  │
│  └──────────────────────────────────────────────┘  │
│                                                      │
├─────────────────────────────────────────────────────┤
│         LÓGICA DE NEGÓCIO (Classes Python)          │
│                                                      │
│  ┌─────────────────────────────────────────────┐   │
│  │         PomodoroApp                          │   │
│  │  (Herda de customtkinter.CTk)               │   │
│  │  ├─ _criar_interface()                      │   │
│  │  ├─ _iniciar_timer()                        │   │
│  │  ├─ _atualizar_timer() [Loop 1s]            │   │
│  │  └─ _finalizar_sessao() [Thread]            │   │
│  └─────────────────────────────────────────────┘   │
│                                                      │
│  ┌─────────────────────────────────────────────┐   │
│  │       PomodoroTimer                          │   │
│  │  ├─ tempo_restante: 25*60 segundos           │   │
│  │  ├─ iniciar() → registra início              │   │
│  │  ├─ parar() → registra fim                   │   │
│  │  ├─ decrementar() → -1s/iteração             │   │
│  │  └─ obter_tempo_formatado() → "MM:SS"       │   │
│  └─────────────────────────────────────────────┘   │
│                                                      │
├─────────────────────────────────────────────────────┤
│         INTEGRAÇÃO COM NOTION (API)                 │
│                                                      │
│  ┌─────────────────────────────────────────────┐   │
│  │      NotionService                           │   │
│  │  ├─ Client(auth=api_key)                    │   │
│  │  ├─ _verify_connection()                    │   │
│  │  └─ registrar_sessao()                      │   │
│  │     └─ client.pages.create(payload)         │   │
│  └─────────────────────────────────────────────┘   │
│                                                      │
├─────────────────────────────────────────────────────┤
│      ARMAZENAMENTO SEGURO (Variáveis de Ambiente)   │
│                                                      │
│  .env (local - não commitado)                      │
│  ├─ NOTION_API_KEY=secret_...                     │
│  └─ DATABASE_ID=xxxx-xxxx-xxxx-xxxx               │
│                                                      │
├─────────────────────────────────────────────────────┤
│           NOTION DATABASE (Cloud)                   │
│                                                      │
│  Pomodoro Sessions Database                        │
│  ├─ Intervalo (Title)                             │
│  ├─ Inicio (Date/Time)                            │
│  ├─ Fim (Date/Time)                               │
│  └─ Tecnologia (Select)                           │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## 🔄 Fluxo de Execução

### 1️⃣ Inicialização (Startup)

```
main.py
  ↓
PomodoroApp.__init__()
  ├─ ctk.set_appearance_mode("dark")      # Tema
  ├─ load_dotenv()                        # Carrega .env
  ├─ _inicializar_notion()                # Conecta ao Notion
  │   └─ NotionService()
  │       └─ _verify_connection()
  ├─ _criar_interface()                   # Monta GUI
  └─ _atualizar_timer()                   # Inicia loop (1s)
```

### 2️⃣ Usuário Clica em [Iniciar]

```
_iniciar_timer() 
  ├─ Validar: tarefa não vazia?
  ├─ timer.iniciar()
  │   └─ tempo_inicio = datetime.now()    # ISO 8601
  ├─ Mudar label_status: "Focado..."
  └─ Desabilitar btn_iniciar
```

### 3️⃣ Loop de Atualização (1 segundo)

```
_atualizar_timer() [LOOP 1s]
  ├─ Se timer rodando:
  │   ├─ timer.decrementar()              # -1 segundo
  │   ├─ label_timer.configure()          # Atualizar display
  │   └─ Se tempo_restante == 0:
  │       └─ _finalizar_sessao()
  │
  └─ after(1000ms, _atualizar_timer)      # Próxima iteração
```

### 4️⃣ Finalização (Timer = 00:00)

```
_finalizar_sessao()
  ├─ timer.parar()
  │   └─ tempo_fim = datetime.now()       # ISO 8601
  ├─ label_status: "Enviando..."
  │
  └─ threading.Thread(target=_registrar_no_notion)
      │
      └─ [THREAD SEPARADA - não bloqueia GUI]
           │
           ├─ NotionService.registrar_sessao()
           │   ├─ Formatar payload:
           │   │   {
           │   │     "Intervalo": {tarefa},
           │   │     "Inicio": {tempo_inicio},
           │   │     "Fim": {tempo_fim},
           │   │     "Tecnologia": {categoria}
           │   │   }
           │   │
           │   └─ client.pages.create(payload)
           │
           ├─ Se sucesso:
           │   └─ label_status: "✓ Sucesso!"
           │
           └─ Se erro:
               └─ label_status: "✗ Erro ao enviar"
```

---

## 🧵 Threading - Segurança de Concorrência

### Thread Principal (GUI)

```python
# Roda continuamente
_atualizar_timer()          # 1s de intervalo
_criar_interface()          # Responde a eventos
_iniciar_timer()            # Cliques do usuário
```

### Thread Secundária (Notion)

```python
# Executada quando timer finaliza
_registrar_no_notion()      # Operação I/O (HTTP)
                            # Não bloqueia GUI
```

**Vantagem:** Usuário não vê interface "congelada" enquanto envia dados

---

## 🔐 Segurança e Boas Práticas

### 1. Sem Hardcoding

```python
# ❌ ERRADO
api_key = "secret_xxxxx"

# ✅ CORRETO
load_dotenv()
api_key = os.getenv("NOTION_API_KEY")
```

### 2. Validação de Credenciais

```python
if not api_key or not database_id:
    logger.error("Variáveis não encontradas!")
    return None
```

### 3. Tratamento de Erros

```python
try:
    response = client.pages.create(...)
    return True
except Exception as e:
    logger.error(f"Erro: {str(e)}")
    return False
```

### 4. Encapsulamento

```python
class NotionService:
    def _verify_connection(self):      # Privado (_)
        pass
    
    def registrar_sessao(self):         # Público
        pass
```

### 5. Type Hints

```python
def registrar_sessao(self, 
                    intervalo: str, 
                    inicio: datetime, 
                    fim: datetime, 
                    tecnologia: str) -> bool:
    pass
```

---

## 📊 Estrutura de Classes

### NotionService

```python
class NotionService:
    
    def __init__(self, api_key: str, database_id: str)
        # Inicializa cliente e verifica conexão
    
    def _verify_connection(self) -> None
        # Valida acesso à database
        # Log de sucesso/erro
    
    def registrar_sessao(self,
                        intervalo: str,
                        inicio: datetime,
                        fim: datetime,
                        tecnologia: str) -> bool
        # Envia dados para Notion
        # Retorna True/False para sucesso
```

### PomodoroTimer

```python
class PomodoroTimer:
    
    TEMPO_PADRAO = 25 * 60  # Constante
    
    def __init__(self)
        # Inicializa tempo em 25 min
    
    def iniciar(self) -> None
        # Registra datetime.now() como início
    
    def parar(self) -> None
        # Registra datetime.now() como fim
    
    def resetar(self) -> None
        # Volta para 25 min
    
    def decrementar(self) -> None
        # Reduz 1 segundo
    
    def obter_tempo_formatado(self) -> str
        # Retorna "MM:SS"
    
    def esta_finalizado(self) -> bool
        # Verifica se tempo_restante == 0
```

### PomodoroApp(ctk.CTk)

```python
class PomodoroApp(ctk.CTk):
    
    def __init__(self)
        # Inicializa janela e interface
    
    def _inicializar_notion(self) -> NotionService | None
        # Carrega .env e cria NotionService
    
    def _criar_interface(self) -> None
        # Monta widgets (Entry, ComboBox, Buttons, etc)
    
    def _iniciar_timer(self) -> None
        # Inicia cronômetro com validações
    
    def _resetar_timer(self) -> None
        # Reseta tudo para o estado inicial
    
    def _atualizar_timer(self) -> None
        # Loop principal (1s de intervalo)
    
    def _finalizar_sessao(self) -> None
        # Chama registrar em thread separada
    
    def _registrar_no_notion(self, ...) -> None
        # Executa em thread - comunica com Notion
    
    def on_closing(self) -> None
        # Limpeza ao fechar janela
```

---

## 📦 Dependências e Propósitos

| Pacote | Versão | Função |
|--------|--------|--------|
| **customtkinter** | 5.2.2 | GUI moderna com Dark Mode |
| **python-dotenv** | 1.0.1 | Carregar `.env` seguramente |
| **notion-client** | 2.2.1 | Comunicar com API Notion |
| **httpx** | 0.26.0 | HTTP client (dependência do notion-client) |

---

## 🎯 Conceitos Python Avançados Utilizados

✅ **Programação Orientada a Objetos**
- Classes, herança, encapsulamento

✅ **Herança**
```python
class PomodoroApp(ctk.CTk):  # Herda de CTk
    pass
```

✅ **Métodos Privados**
```python
def _verify_connection(self):   # Privado (começa com _)
    pass
```

✅ **Type Hints**
```python
def registrar_sessao(self, ...) -> bool:
    pass
```

✅ **Threading**
```python
threading.Thread(target=_registrar_no_notion, daemon=True)
```

✅ **Context Managers**
```python
with open('.env') as f:
    pass
```

✅ **Logging**
```python
logger.info("Mensagem informativa")
logger.error("Mensagem de erro")
```

✅ **Tratamento de Exceções**
```python
try:
    client.pages.create(...)
except Exception as e:
    logger.error(f"Erro: {str(e)}")
```

✅ **Variáveis de Ambiente**
```python
api_key = os.getenv("NOTION_API_KEY")
```

✅ **Callbacks (Eventos da GUI)**
```python
btn_iniciar = CTkButton(..., command=self._iniciar_timer)
```

---

## 🚀 Fluxo Completo de Uso

```
1. Usuário executa: python main.py
   └─ Interface abre com tema Dark Mode

2. Usuário digita tarefa: "Implementar login"
   └─ Entry widget salva o texto

3. Usuário seleciona categoria: "Python"
   └─ ComboBox armazena seleção

4. Usuário clica [Iniciar]
   └─ timer.iniciar() registra datetime.now()
   └─ Timer começa a decrementar
   └─ Label de status: "Focado..."

5. A cada segundo (loop _atualizar_timer):
   └─ timer.decrementar()
   └─ label_timer atualiza display (24:59, 24:58, ...)

6. Quando chega a 00:00
   └─ _finalizar_sessao() é chamado
   └─ Nova thread: _registrar_no_notion()
   └─ Notion recebe: 
      {
        "Intervalo": "Implementar login",
        "Inicio": "2024-01-23T14:00:00",
        "Fim": "2024-01-23T14:25:00",
        "Tecnologia": "Python"
      }

7. Sucesso no Notion
   └─ Label status: "✓ Sucesso!"
   └─ Botão [Iniciar] reabalitado
   └─ Usuário pode começar nova sessão

8. Usuário pode clicar [Resetar]
   └─ Limpa campos
   └─ Timer volta a 25:00
```

---

## 🧪 Como Testar

### Via Command Line

```bash
# Verificar dependências
python tests.py deps

# Validar .env
python tests.py env

# Testar Notion
python tests.py notion

# Registrar sessão teste
python tests.py registro

# Tudo
python tests.py all
```

### Via Menu Interativo

```bash
python tests.py
# Menu aparece com 6 opções
```

---

## 📈 Possíveis Melhorias Futuras

- [ ] Banco de dados local (SQLite) para backup offline
- [ ] Notificação de som/vibração ao fim da sessão
- [ ] Histórico de sessões na própria GUI
- [ ] Configuração de tempo customizável (não apenas 25 min)
- [ ] Pausar/Retomar sessão
- [ ] Tema claro (Light Mode)
- [ ] Sincronização com Google Calendar
- [ ] Estatísticas e relatórios
- [ ] Autenticação do usuário

---

**Desenvolvido com ❤️ em Python**

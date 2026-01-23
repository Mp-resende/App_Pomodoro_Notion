# 🍅 Pomodoro Dev Tracker

**Cronômetro Pomodoro profissional com integração automática ao Notion**

Um aplicativo de gerenciamento de foco desenvolvido em Python com interface moderna (Dark Mode) que registra automaticamente suas sessões Pomodoro em uma database do Notion.

---

## 🚀 Características

✅ **Interface Moderna** - Tema Dark Mode com customtkinter  
✅ **Timer Pomodoro** - 25 minutos de foco ininterrupto  
✅ **Categorização** - Selecione a tecnologia/categoria de trabalho  
✅ **Integração Notion** - Registra automático de sessões  
✅ **Segurança** - Credenciais gerenciadas via `.env` (sem hardcoding)  
✅ **Thread Safety** - Envio ao Notion sem travar a interface  
✅ **Timestamps Precisos** - Registra início e término em ISO 8601  
✅ **Orientado a Objetos** - Código limpo, modulado e profissional  

---

## 📋 Pré-requisitos

- Python 3.8+
- pip (gerenciador de pacotes Python)
- Conta Notion com permissões de integração

---

## 🔧 Instalação

### 1. Criar um ambiente virtual (recomendado)

```bash
python -m venv venv
source venv/bin/activate  # No Windows: venv\Scripts\activate
```

### 2. Instalar as dependências

```bash
pip install -r requirements.txt
```

**Ou instale manualmente:**

```bash
pip install customtkinter==5.2.2
pip install python-dotenv==1.0.1
pip install notion-client==2.2.1
pip install httpx==0.26.0
```

---

## 🔑 Configuração do Notion

### Passo 1: Criar uma Integração Notion

1. Acesse: https://www.notion.so/my-integrations
2. Clique em **"New integration"**
3. Dê um nome (ex: "Pomodoro Dev Tracker")
4. Selecione seu workspace
5. Copie o **"Internal Integration Token"** (será seu `NOTION_API_KEY`)

### Passo 2: Criar a Database Notion

1. No Notion, crie uma nova page/database
2. Adicione as seguintes propriedades:

| Propriedade | Tipo | Descrição |
|-------------|------|-----------|
| **Intervalo** | Title | Nome da tarefa |
| **Inicio** | Date | Data/hora de início (ISO 8601) |
| **Fim** | Date | Data/hora de término (ISO 8601) |
| **Tecnologia** | Select | Opções: Python, C#, SQL, n8n, Arquitetura, Outros |

3. **Compartilhe a database com a integração:**
   - Clique em "Share" no canto superior direito
   - Procure pela integração criada e adicione com acesso
4. **Copie o DATABASE_ID:**
   - URL da database: `https://www.notion.so/seu-workspace/[DATABASE_ID]?v=...`
   - O DATABASE_ID é a string de 32 caracteres após o workspace

### Passo 3: Configurar o arquivo `.env`

1. Renomeie `.env.example` para `.env`
2. Preencha com suas credenciais:

```env
NOTION_API_KEY=seu_token_notion_aqui
DATABASE_ID=seu_database_id_de_32_caracteres
```

**⚠️ IMPORTANTE:** Nunca commit do `.env` no Git. Já está no `.gitignore`.

---

## ▶️ Executar a Aplicação

```bash
python main.py
```

A interface gráfica será aberta automaticamente.

---

## 📱 Como Usar

1. **Digite a tarefa** no campo "O que vai codar hoje?"
2. **Selecione a categoria** (Python, C#, SQL, etc.)
3. **Clique em [Iniciar]** para começar o timer de 25 minutos
4. **Foque no desenvolvimento** enquanto o timer roda
5. **Ao finalizar**, a sessão é enviada automaticamente para o Notion
6. **Clique em [Resetar]** para começar uma nova sessão

---

## 🔒 Segurança

### ✅ Boas Práticas Implementadas

- **Sem Hardcoding**: Chaves de API carregadas via `python-dotenv`
- **Verificação de Credenciais**: Aplicação valida se as variáveis foram carregadas
- **Isolamento de Threads**: Envio ao Notion não bloqueia a interface
- **Tratamento de Erros**: Logs informativos de sucesso/falha
- **Validação de Entrada**: Tarefa não pode estar vazia

### 📝 Arquivo `.env` - NUNCA compartilhe

```env
# Exemplo (use seus próprios valores)
NOTION_API_KEY=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DATABASE_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 🏗️ Arquitetura do Código

```
main.py
├── NotionService          # Gerencia integração com Notion
│   ├── _verify_connection()   # Valida conexão
│   └── registrar_sessao()     # Envia dados ao Notion
├── PomodoroTimer          # Lógica do timer
│   ├── iniciar()
│   ├── parar()
│   ├── resetar()
│   └── decrementar()
└── PomodoroApp            # GUI Principal (customtkinter)
    ├── _criar_interface()     # Monta a interface
    ├── _inicializar_notion()  # Carrega credenciais
    ├── _iniciar_timer()       # Inicia o cronômetro
    ├── _finalizar_sessao()    # Finaliza e envia ao Notion
    └── _atualizar_timer()     # Loop de atualização (1s)
```

---

## 🐛 Troubleshooting

### ❌ "Erro: Variáveis de ambiente não encontradas"

**Solução:**
- Certifique-se de que o arquivo `.env` está na **raiz do projeto**
- Verifique se tem as chaves `NOTION_API_KEY` e `DATABASE_ID`
- Reinicie a aplicação após salvar o `.env`

```bash
# Verificar se o .env existe
ls -la .env
```

### ❌ "Erro ao conectar ao Notion"

**Possíveis causas:**
- Token inválido ou expirado
- Database ID incorreto
- Integração não compartilhada com a database
- Conexão de internet instável

**Solução:**
1. Regenere o token em: https://www.notion.so/my-integrations
2. Verifique o ID da database (32 caracteres)
3. Compartilhe a integração com a database novamente

### ❌ "ModuleNotFoundError: No module named 'customtkinter'"

**Solução:**
```bash
pip install --upgrade customtkinter
```

### ❌ Interface fica "congelada" após clicar em Iniciar

Não é congelamento! A aplicação está aguardando o timer completar 25 minutos. Isso é normal. Os controles serão reativados ao finalizar.

---

## 📊 Exemplos de Registros no Notion

| Intervalo | Inicio | Fim | Tecnologia |
|-----------|--------|-----|-----------|
| Implementar autenticação | 2024-01-23T14:00:00 | 2024-01-23T14:25:00 | Python |
| Refatorar controllers | 2024-01-23T14:30:00 | 2024-01-23T14:55:00 | C# |
| Otimizar queries | 2024-01-23T15:00:00 | 2024-01-23T15:25:00 | SQL |

---

## 🛠️ Desenvolvimento

### Estrutura de Classes

**NotionService**
```python
class NotionService:
    - __init__(api_key, database_id)
    - _verify_connection() -> None
    - registrar_sessao(intervalo, inicio, fim, tecnologia) -> bool
```

**PomodoroTimer**
```python
class PomodoroTimer:
    - iniciar() -> None
    - parar() -> None
    - resetar() -> None
    - decrementar() -> None
    - obter_tempo_formatado() -> str
    - esta_finalizado() -> bool
```

**PomodoroApp(ctk.CTk)**
```python
class PomodoroApp(ctk.CTk):
    - _criar_interface() -> None
    - _inicializar_notion() -> NotionService | None
    - _iniciar_timer() -> None
    - _resetar_timer() -> None
    - _finalizar_sessao() -> None
    - _registrar_no_notion(...) -> None [Thread]
    - _atualizar_timer() -> None [Loop]
```

---

## 📦 Dependências Detalhadas

| Pacote | Versão | Função |
|--------|--------|--------|
| **customtkinter** | 5.2.2 | Interface gráfica moderna |
| **python-dotenv** | 1.0.1 | Carrega variáveis de `.env` |
| **notion-client** | 2.2.1 | Cliente oficial da API Notion |
| **httpx** | 0.26.0 | HTTP client (dependência do notion-client) |

---

## 🎓 Conceitos Python Implementados

- ✅ Programação Orientada a Objetos (POO)
- ✅ Herança (PomodoroApp herda de ctk.CTk)
- ✅ Encapsulamento (métodos privados com `_`)
- ✅ Threading (separação de responsabilidades)
- ✅ Type Hints (anotações de tipo)
- ✅ Context Managers (with statements)
- ✅ Logging (rastreamento de eventos)
- ✅ Tratamento de Exceções (try/except)
- ✅ Variáveis de Ambiente (segurança)
- ✅ Callbacks (eventos da GUI)

---

## 📄 Licença

Desenvolvido como exemplo educacional de Python profissional.

---

## 👨‍💻 Autor

**Desenvolvedor Python Sênior**  
Especialista em GUI com customtkinter e integração de APIs

---

## 📞 Suporte

Para dúvidas sobre:
- **Notion API**: https://developers.notion.com/reference
- **customtkinter**: https://github.com/TomSchimansky/CustomTkinter
- **python-dotenv**: https://github.com/theskumar/python-dotenv

---

**Happy Coding! 🚀**
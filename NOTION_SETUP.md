# 📚 GUIA DE CONFIGURAÇÃO NOTION - Pomodoro Dev Tracker

## 🎯 Objetivo
Este guia detalha como configurar a database no Notion para funcionar com o Pomodoro Dev Tracker.

---

## 1️⃣ Criar uma Integração no Notion

### Passo a passo:

1. **Acesse** https://www.notion.so/my-integrations
2. **Clique em** "New integration" (botão azul no topo)
3. **Preencha os dados:**
   - Name: "Pomodoro Dev Tracker"
   - Workspace: Selecione seu workspace
   - User capabilities: Deixe no padrão
4. **Clique em** "Submit"
5. **Copie o Token:**
   - Você verá um campo "Internal Integration Secret" ou "Token"
   - Clique em "Show" e depois "Copy"
   - **Cole em `.env` na variável `NOTION_API_KEY`**

---

## 2️⃣ Criar a Database no Notion

### Estrutura esperada:

A database deve ter **EXATAMENTE** as seguintes propriedades:

```
┌─────────────────────────────────────────────────────┐
│              Pomodoro Sessions                      │
├─────────────────────────────────────────────────────┤
│ Intervalo (Title)           | Nome da tarefa       │
│ Inicio (Date)              | Data/hora de início  │
│ Fim (Date)                 | Data/hora de término │
│ Tecnologia (Select)        | Categoria (dropdown) │
└─────────────────────────────────────────────────────┘
```

### Criando cada propriedade:

#### 📌 Propriedade 1: "Intervalo" (Já existe por padrão como "Title")

- **Nome:** Intervalo
- **Tipo:** Title
- *Descrição:* O texto da tarefa digitada pelo usuário
- *Exemplo:* "Implementar autenticação"

#### 📅 Propriedade 2: "Inicio" (Date)

1. Clique no "+" para adicionar nova propriedade
2. **Nome:** Inicio
3. **Tipo:** Date
4. **Date format:** Selecione "Date & time" (importante!)
5. *Descrição:* Timestamp de quando começou o Pomodoro
6. *Exemplo:* 2024-01-23 14:00 (ISO 8601)

#### 📅 Propriedade 3: "Fim" (Date)

1. Clique no "+" para adicionar nova propriedade
2. **Nome:** Fim
3. **Tipo:** Date
4. **Date format:** Selecione "Date & time" (importante!)
5. *Descrição:* Timestamp de quando terminou o Pomodoro
6. *Exemplo:* 2024-01-23 14:25 (ISO 8601)

#### 🏷️ Propriedade 4: "Tecnologia" (Select)

1. Clique no "+" para adicionar nova propriedade
2. **Nome:** Tecnologia
3. **Tipo:** Select
4. **Adicione as opções:**
   - Python
   - C#
   - SQL
   - n8n
   - Arquitetura
   - Outros
5. *Descrição:* Categoria de trabalho
6. *Exemplo:* Python

**Como adicionar as opções:**
- Clique em "Create option"
- Digite o nome (ex: "Python")
- Escolha uma cor (opcional)
- Clique em "Done"
- Repita para cada opção

---

## 3️⃣ Compartilhar a Database com a Integração

### ⚠️ IMPORTANTE: Sem este passo, a integração não terá acesso!

1. Abra sua database no Notion
2. Clique em **"Share"** (botão no canto superior direito)
3. Procure por **"Connections"** ou **"Connections & invites"**
4. Clique em **"Add"** ou **"Invite"**
5. Procure pela integração que você criou (ex: "Pomodoro Dev Tracker")
6. Selecione com as permissões adequadas (**Editor** ou **Full Access**)
7. Clique em **"Invite"** ou **"Confirm"**

---

## 4️⃣ Obter o DATABASE_ID

### Método 1: Da URL (Mais fácil)

1. Abra a database no Notion
2. Copie a URL da barra de endereços:
   ```
   https://www.notion.so/seu-workspace/[DATABASE_ID]?v=xxxxx
   ```
3. O `DATABASE_ID` é a string de 32 caracteres (com hífens)
4. **Cole em `.env` na variável `DATABASE_ID`**

### Método 2: Usando o Notion Web Clipper

1. No Notion, pressione `Ctrl+Shift+V` (ou `Cmd+Shift+V` no Mac)
2. Copie o "Page ID" que aparece
3. Use esse valor como `DATABASE_ID`

---

## ✅ Verificação Final

Antes de executar a aplicação, certifique-se de:

- [ ] Integração criada em https://www.notion.so/my-integrations
- [ ] Token copiado e salvo em `.env` como `NOTION_API_KEY`
- [ ] Database criada no Notion com as 4 propriedades corretas
- [ ] Integração compartilhada com a database
- [ ] DATABASE_ID copiado e salvo em `.env`
- [ ] Arquivo `.env` está na raiz do projeto
- [ ] Arquivo `.env` é gitignored (não fazer commit!)

---

## 🧪 Teste de Conexão

Execute o comando abaixo para testar a conexão:

```bash
python3 << 'EOF'
from dotenv import load_dotenv
import os
from notion_client import Client

load_dotenv()
api_key = os.getenv("NOTION_API_KEY")
database_id = os.getenv("DATABASE_ID")

if not api_key or not database_id:
    print("❌ Variáveis de ambiente não encontradas!")
else:
    try:
        client = Client(auth=api_key)
        db = client.databases.retrieve(database_id=database_id)
        print("✅ Conexão com Notion bem-sucedida!")
        print(f"Database: {db['title']}")
    except Exception as e:
        print(f"❌ Erro: {str(e)}")
EOF
```

---

## 📋 Exemplo Final do `.env`

```env
# Seu token da integração Notion (começa com "secret_")
NOTION_API_KEY=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ID da database (32 caracteres com hífens)
DATABASE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## 🆘 Solução de Problemas

### ❌ "Invalid key provided"
**Causa:** O token está inválido ou expirado  
**Solução:** Regenere o token em https://www.notion.so/my-integrations

### ❌ "Could not find database with ID"
**Causa:** O DATABASE_ID está incorreto ou a integração não está compartilhada  
**Solução:**  
1. Verifique se o ID tem 32 caracteres
2. Compartilhe a database com a integração novamente

### ❌ "User does not have access to resource"
**Causa:** A integração não tem acesso à database  
**Solução:** Refaça o compartilhamento da database

### ❌ Os dados não aparecem no Notion
**Causa:** Propriedades com nomes incorretos  
**Solução:** Certifique-se de que as propriedades têm **EXATAMENTE** esses nomes:
- "Intervalo" (não "intervalo")
- "Inicio" (não "Início")
- "Fim"
- "Tecnologia" (não "Categoria")

---

## 📞 Referências

- **Notion API Docs:** https://developers.notion.com/reference
- **Como criar integrações:** https://www.notion.so/my-integrations
- **Python client library:** https://github.com/ramnes/notion-sdk-py

---

**Tudo pronto? Execute `python main.py` e comece a rastrear suas sessões! 🍅**

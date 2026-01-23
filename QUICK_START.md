# ⚡ Quick Start - Pomodoro Dev Tracker

**Comece em 5 minutos!**

---

## 🚀 Instalação Rápida

### 1. Instale as dependências
```bash
pip install -r requirements.txt
```

### 2. Configure as credenciais
```bash
cp .env.example .env
# Edite .env com suas credenciais do Notion
```

### 3. Execute a aplicação
```bash
python main.py
```

---

## 📝 Obter Credenciais do Notion (2 minutos)

### NOTION_API_KEY
1. Vá para: https://www.notion.so/my-integrations
2. Clique em "New integration"
3. Dê um nome e crie
4. **Copie o "Internal Integration Secret"**
5. Cole em `.env` como `NOTION_API_KEY`

### DATABASE_ID
1. No Notion, crie uma database com as propriedades:
   - `Intervalo` (Title)
   - `Inicio` (Date - com hora)
   - `Fim` (Date - com hora)
   - `Tecnologia` (Select com: Python, C#, SQL, n8n, Arquitetura, Outros)
2. Compartilhe a database com sua integração
3. **Copie a URL da database:**
   ```
   https://www.notion.so/workspace/[DATABASE_ID]?v=xxxxx
   ```
4. O `DATABASE_ID` é a string de 32 caracteres
5. Cole em `.env` como `DATABASE_ID`

---

## 🎮 Como Usar

1. **Digite a tarefa** (ex: "Implementar login")
2. **Selecione a categoria** (ex: "Python")
3. **Clique [Iniciar]** - Timer começa (25 min)
4. **Quando terminar** - Automaticamente envia ao Notion
5. **Clique [Resetar]** para nova sessão

---

## ✅ Checklist Final

- [ ] `requirements.txt` instalado
- [ ] Arquivo `.env` criado (copie `.env.example`)
- [ ] `NOTION_API_KEY` preenchido
- [ ] `DATABASE_ID` preenchido
- [ ] Database criada no Notion
- [ ] Integração compartilhada com database

---

## 📋 Exemplo de `.env`

```env
NOTION_API_KEY=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DATABASE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## 🔒 Segurança

⚠️ **Nunca commit o arquivo `.env`**  
✅ Já está no `.gitignore` - protegido automaticamente

---

## 🐛 Algo não funciona?

1. **Erro de conexão Notion?**
   - Verifique se os valores em `.env` estão corretos
   - Regenere o token em https://www.notion.so/my-integrations
   - Compartilhe a database novamente com a integração

2. **ModuleNotFoundError?**
   ```bash
   pip install --upgrade customtkinter
   ```

3. **Interface congelada?**
   - Não é congelamento! O timer está rodando
   - Quando chegar a 00:00, enviará para o Notion

---

## 📚 Documentação Completa

- [README.md](README.md) - Guia completo
- [NOTION_SETUP.md](NOTION_SETUP.md) - Configuração detalhada do Notion
- [main.py](main.py) - Código bem comentado

---

**Pronto para começar? Execute:**
```bash
python main.py
```

🍅 Happy Pomodoro! 🚀

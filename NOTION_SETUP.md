# 📚 GUIA DE CONFIGURAÇÃO NOTION - Pomodoro Dev Tracker

## 🎯 Objetivo
Este guia detalha como estruturar e configurar a arquitetura de banco de dados relacionais no seu Notion para funcionar com o **Pomodoro Dev Tracker**. A versão Flutter utiliza um modelo relacional de **três bases de dados** para gerar gráficos interativos de matérias, metas e tópicos no Dashboard.

---

## 🏗️ Arquitetura das Databases no Notion

Para usufruir de todas as funcionalidades (filtros, metas semanais e tópicos estudados), a integração necessita de 3 tabelas conectadas:

```
  ┌────────────────────────────────────────────────────────┐
  │                 1. Matérias                            │◄──────┐
  ├────────────────────────────────────────────────────────┤       │
  │ Nome (Title)            | Ex: "Desenvolvimento Dart"   │       │
  │ Área (Select)           | Ex: "Programação"            │       │ (Relação 1-N)
  │ Meta Semanal (h) (Num)  | Ex: 10                       │       │
  └────────────────────────────────────────────────────────┘       │
                               ▲                                   │
                               │ (Relação 1-N)                     │
  ┌────────────────────────────┴───────────────────────────┐       │
  │                 2. Estudos Diários (Tópicos)           │       │
  ├────────────────────────────────────────────────────────┤       │
  │ Tópico (Title)          | Ex: "Flutter Navigation"     │       │
  │ Tipo de Estudo (Select) | Teoria / Prática / Revisão   │       │
  │ Banco de Dados: Matérias| Relação para Matérias (Tab 1)│───────┘
  └────────────────────────────▲───────────────────────────┘
                               │
                               │ (Relação 1-N)
  ┌────────────────────────────┴───────────────────────────┐
  │                 3. Intervalos de Foco (DATABASE_ID)    │
  ├────────────────────────────────────────────────────────┤
  │ Intervalo (Title)       | Ex: "Estudar Provider"       │
  │ Início (Date)           | Data/Hora inicial            │
  │ Fim (Date)              | Data/Hora final              │
  │ Tecnologia (Select)     | Ex: Flutter, Python, SQL     │
  │ Sessão de Estudo (Rel)  | Relação para Estudos Diários │
  └────────────────────────────────────────────────────────┘
```

---

## 1️⃣ Configurando a Database 1: Matérias (subjects)
*Esta database guarda as matérias principais de estudo e suas respectivas metas de horas semanais.*

*   **DATABASE_ID (Padrão no código):** `2aa75b83-d245-80a5-a194-ede969ff4e45`
*   **Propriedades:**
    1.  **Nome** (Título / Title): Nome da matéria (Ex: `Flutter & Dart`, `Banco de Dados`).
    2.  **Área** (Seleção / Select): Categoria da matéria (Ex: `Programação`, `Design`, `Matemática`).
    3.  **Meta Semanal (h)** (Número / Number): Quantidade de horas que deseja focar por semana (Ex: `12`, `8.5`).

---

## 2️⃣ Configurando a Database 2: Estudos Diários (Tópicos)
*Esta database funciona como os tópicos ou submódulos estudados no dia a dia.*

*   **DATABASE_ID (Padrão no código):** `2aa75b83-d245-80d9-b29e-c362f3ebbd09`
*   **Propriedades:**
    1.  **Nome** (Título / Title): Tópico específico de estudo (Ex: `Gerência de Estado Provider`, `Normalização de tabelas`).
    2.  **Tipo de Estudo** (Seleção / Select): Crie exatamente as seguintes opções (com acento):
        *   `Teoria`
        *   `Prática`
        *   `Revisão`
    3.  **Banco de Dados: Matérias** (Relação / Relation):
        *   Crie uma relação apontando para a database **Matérias (Tab 1)**.
        *   Configure como relação de sentido único ou bilateral, de modo que cada tópico aponte para sua respectiva matéria principal.

---

## 3️⃣ Configurando a Database 3: Intervalos de Foco (Principal)
*Esta é a base onde o timer Pomodoro registra os blocos de tempo trabalhados. O ID desta base é configurado no seu arquivo `.env`.*

*   **DATABASE_ID:** Configurado via `DATABASE_ID` no arquivo `.env` da raiz do projeto.
*   **Propriedades:**
    1.  **Intervalo** (Título / Title): Descrição resumida da tarefa de foco (Ex: `Implementar controllers de autenticação`).
    2.  **Início** (Data / Date): Timestamp de início. Certifique-se de ativar "Include time" na visualização do Notion.
    3.  **Fim** (Data / Date): Timestamp de término.
    4.  **Tecnologia** (Seleção / Select): dropdown com as stacks/linguagens (Ex: `Flutter`, `Python`, `C#`, `SQL`, `n8n`).
    5.  **Sessão de Estudo** (Relação / Relation):
        *   Crie uma relação apontando para a database **Estudos Diários (Tab 2)**.
        *   Isso vincula o bloco de tempo cronometrado diretamente ao tópico estudado.

---

## 4️⃣ Criar a Integração no Notion e Compartilhar

1.  Acesse https://www.notion.so/my-integrations.
2.  Clique em **"New integration"** e crie com o nome "Pomodoro Dev Tracker".
3.  Copie o **"Internal Integration Secret"** gerado e salve-o no seu arquivo `.env` na propriedade `NOTION_API_KEY`.
4.  **⚠️ IMPORTANTE - Compartilhar Databases:**
    *   Abra cada uma das **três** bases de dados no Notion.
    *   Em todas elas, clique no botão **Share** (canto superior direito).
    *   Adicione a conexão da integração que você criou ("Pomodoro Dev Tracker") com permissão de **Editor** ou **Acesso Total**.

---

## 📄 Exemplo do Arquivo `.env` na Raiz do Projeto

```env
# Seu token da integração Notion (começa com "secret_")
NOTION_API_KEY=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# ID da Database 3 (Intervalos de Foco - 32 caracteres com hífens)
DATABASE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## 🧪 Testando a Integração

Você pode rodar o script de verificação rápida no terminal do projeto para garantir que o Python/Notion Client está com todas as conexões prontas e ativas:

```bash
python check_notion.py
```

Se a configuração estiver correta, o script imprimirá a confirmação de comunicação e leitura das três tabelas da sua estrutura relacional do Notion.

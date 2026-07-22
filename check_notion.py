import urllib.request
import json
import sys
import os

# Função manual para carregar .env sem dependências externas
def ler_env(caminho=".env"):
    env = {}
    if not os.path.exists(caminho):
        return env
    try:
        with open(caminho, "r", encoding="utf-8") as f:
            for linha in f:
                linha = linha.strip()
                if not linha or linha.startswith("#"):
                    continue
                partes = linha.split("=", 1)
                if len(partes) == 2:
                    chave = partes[0].strip()
                    valor = partes[1].strip().strip("'").strip('"')
                    env[chave] = valor
    except Exception as e:
        print(f"[AVISO] Erro ao ler arquivo .env: {e}")
    return env

def requisicao_notion(url, token, metodo="GET", dados=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json"
    }
    
    corpo = None
    if dados:
        corpo = json.dumps(dados).encode("utf-8")
        
    req = urllib.request.Request(url, data=corpo, headers=headers, method=metodo)
    
    try:
        with urllib.request.urlopen(req) as res:
            return True, json.loads(res.read().decode("utf-8")), None
    except urllib.error.HTTPError as e:
        try:
            erro_corpo = json.loads(e.read().decode("utf-8"))
            return False, None, f"HTTP {e.code}: {erro_corpo.get('message', e.reason)}"
        except Exception:
            return False, None, f"HTTP {e.code}: {e.reason}"
    except Exception as e:
        return False, None, str(e)

def diagnosticar():
    print("=== INICIANDO DIAGNOSTICO DE CONEXAO COM O NOTION ===\n")
    
    # 1. Carregar arquivo .env
    caminho_env = ".env"
    if not os.path.exists(caminho_env):
        print("[ERRO] Arquivo `.env` nao encontrado na raiz do projeto!")
        print("DICA: Crie um arquivo chamado `.env` baseado no `.env.example`.")
        return
        
    env = ler_env(caminho_env)
    
    token = env.get("NOTION_API_KEY")
    db_id = env.get("DATABASE_ID")
    
    if not token:
        print("[ERRO] Variavel NOTION_API_KEY nao encontrada no `.env`!")
        return
    if not db_id:
        print("[ERRO] Variavel DATABASE_ID nao encontrada no `.env`!")
        return
        
    print("Configuracoes detectadas:")
    exibicao_token = token[:10] + "..." if len(token) > 10 else token
    print(f"   - NOTION_API_KEY: {exibicao_token}")
    print(f"   - DATABASE_ID:    {db_id}\n")
    
    # 2. Testar Token (Autenticação da Integração)
    print("Testando Token de Integracao (notion.com/v1/users/me)...")
    sucesso_auth, dados_auth, erro_auth = requisicao_notion("https://api.notion.com/v1/users/me", token)
    
    if not sucesso_auth:
        print(f"[ERRO] Falha de Autenticacao: {erro_auth}")
        print("Dicas de causas possiveis:")
        print("   - O token inserido no `.env` esta incorreto ou incompleto.")
        print("   - O token expirou ou a integracao foi deletada no painel do Notion.")
        return
    
    nome_integracao = dados_auth.get("name", "Integracao Sem Nome")
    print(f"[OK] Token VALIDO! Conectado como integracao: '{nome_integracao}'\n")
    
    # 3. Testar Acesso à Database
    print(f"Testando acesso a Database (notion.com/v1/databases/{db_id})...")
    sucesso_db, dados_db, erro_db = requisicao_notion(f"https://api.notion.com/v1/databases/{db_id}", token)
    
    if not sucesso_db:
        print(f"[ERRO] Falha de Acesso a Database: {erro_db}")
        print("Dicas de causas possiveis:")
        print("   - O DATABASE_ID fornecido esta incorreto.")
        print("   - A integracao nao foi compartilhada com a Database no Notion!")
        print("     Como corrigir: Abra a pagina da database no Notion, clique em 'Share' (Compartilhar),")
        print(f"     procure por '{nome_integracao}' nas conexoes e adicione-a como Editor/Acesso Completo.")
        return
        
    titulo_lista = dados_db.get("title", [])
    titulo_db = titulo_lista[0].get("plain_text", "Sem Titulo") if titulo_lista else "Sem Titulo"
    print(f"[OK] Acesso a Database VALIDO! Database encontrada: '{titulo_db}'\n")
    
    # 4. Validar Propriedades (Estrutura da Database)
    print("Verificando propriedades (colunas) da Database...")
    propriedades = dados_db.get("properties", {})
    
    propriedades_esperadas = {
        "Intervalo": "title",
        "Início": "date",
        "Fim": "date",
        "Tecnologia": "select"
    }
    
    erros_prop = []
    
    for nome_esp, tipo_esp in propriedades_esperadas.items():
        if nome_esp not in propriedades:
            erros_prop.append(f"Falta a propriedade '{nome_esp}'")
        else:
            tipo_real = propriedades[nome_esp].get("type")
            if tipo_real != tipo_esp:
                erros_prop.append(f"Propriedade '{nome_esp}' deveria ser do tipo '{tipo_esp}', mas eh '{tipo_real}'")
                
    if erros_prop:
        print("[ERRO] A estrutura da Database possui divergencias:")
        for err in erros_prop:
            print(f"   - {err}")
        print("\nColunas atualmente encontradas no Notion:")
        for nome_real, info_real in propriedades.items():
            print(f"   - {nome_real} (tipo: {info_real.get('type')})")
        print("\nDICA: Corrija esses nomes e tipos de propriedades na sua tabela do Notion")
        print("para que o aplicativo consiga enviar os pomodoros corretamente.")
    else:
        print("[OK] Estrutura da Database 100% CORRETA! Todas as propriedades exigidas estao presentes:")
        print("   - Intervalo (tipo: Title)")
        print("   - Inicio (tipo: Date)")
        print("   - Fim (tipo: Date)")
        print("   - Tecnologia (tipo: Select)")
        print("\nTudo certo! O Notion esta configurado e acessivel corretamente para o aplicativo.")

    # 5. Verificar e testar campos de relação (Relações com outras tabelas)
    print("\nVerificando campos de relacao (para associar tarefas/projetos)...")
    campos_relacao = []
    for nome_prop, info_prop in propriedades.items():
        if info_prop.get("type") == "relation":
            campos_relacao.append((nome_prop, info_prop))
            
    if not campos_relacao:
        print("[AVISO] Nenhum campo de relacao encontrado na tabela do Notion.")
        print("        Se voce pretendia relacionar as sessoes com outra tabela de Projetos ou Tarefas,")
        print("        crie uma propriedade do tipo 'Relation' no Notion.")
    else:
        print(f"Detectado(s) {len(campos_relacao)} campo(s) de relacao:")
        for nome_rel, info_rel in campos_relacao:
            rel_info = info_rel.get("relation", {})
            related_db_id = rel_info.get("database_id")
            
            if not related_db_id:
                print(f"   - {nome_rel}: Nao foi possivel obter o ID da base relacionada.")
                continue
                
            print(f"   - {nome_rel} -> Aponta para a base: {related_db_id}")
            print(f"     Testando permissao de leitura na base relacionada...")
            
            url_query = f"https://api.notion.com/v1/databases/{related_db_id}/query"
            sucesso_rel, dados_rel, erro_rel = requisicao_notion(url_query, token, metodo="POST", dados={})
            
            if sucesso_rel:
                opcoes = dados_rel.get("results", [])
                print(f"     [OK] Acesso garantido! Encontradas {len(opcoes)} opcoes disponiveis na base relacionada.")
                if opcoes:
                    print("     Exemplos de registros encontrados:")
                    for op in opcoes[:3]:
                        op_props = op.get("properties", {})
                        title_text = "Sem Nome"
                        for prop_val in op_props.values():
                            if prop_val.get("type") == "title":
                                title_array = prop_val.get("title", [])
                                if title_array:
                                    title_text = title_array[0].get("plain_text", "Sem Nome")
                                break
                        print(f"       * {title_text}")
            else:
                print(f"     [ERRO] Sem acesso a tabela relacionada! Erro: {erro_rel}")
                print("     DICA: Voce deve compartilhar a tabela relacionada no Notion")
                print(f"           com a integracao '{nome_integracao}' tambem!")
                print("           Abra a outra tabela no Notion, clique em 'Share' (Compartilhar),")
                print(f"           e convide a conexao '{nome_integracao}'.")

if __name__ == "__main__":
    diagnosticar()

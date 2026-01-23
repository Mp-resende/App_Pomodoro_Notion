"""
EXEMPLOS E TESTES - Pomodoro Dev Tracker
Arquivo com exemplos de uso e testes da aplicação
"""

# ==================== TESTE 1: VERIFICAR CONEXÃO NOTION ====================
"""
Teste se a integração Notion está funcionando corretamente.
Execute este código antes de rodar main.py
"""

def teste_conexao_notion():
    from dotenv import load_dotenv
    import os
    from notion_client import Client
    
    load_dotenv()
    
    api_key = os.getenv("NOTION_API_KEY")
    database_id = os.getenv("DATABASE_ID")
    
    print("🔍 Testando conexão com Notion...")
    print(f"API Key presente: {'✓' if api_key else '✗'}")
    print(f"Database ID presente: {'✓' if database_id else '✗'}")
    
    if not api_key or not database_id:
        print("❌ Credenciais faltando. Configure .env primeiro.")
        return False
    
    try:
        client = Client(auth=api_key)
        db = client.databases.retrieve(database_id=database_id)
        print(f"✅ Conexão bem-sucedida!")
        print(f"   Database: {db.get('title', 'Sem título')}")
        return True
    except Exception as e:
        print(f"❌ Erro: {str(e)}")
        return False


# ==================== TESTE 2: LISTAR PROPRIEDADES DA DATABASE ====================
"""
Mostra as propriedades da database Notion
"""

def listar_propriedades_database():
    from dotenv import load_dotenv
    import os
    from notion_client import Client
    
    load_dotenv()
    
    api_key = os.getenv("NOTION_API_KEY")
    database_id = os.getenv("DATABASE_ID")
    
    if not api_key or not database_id:
        print("❌ Configure .env primeiro")
        return
    
    try:
        client = Client(auth=api_key)
        db = client.databases.retrieve(database_id=database_id)
        
        print("📋 Propriedades da Database:")
        print("-" * 50)
        
        for prop_name, prop_info in db["properties"].items():
            prop_type = prop_info["type"]
            print(f"  • {prop_name:<20} (Tipo: {prop_type})")
        
        print("-" * 50)
        print("✅ Propriedades listadas com sucesso")
        
    except Exception as e:
        print(f"❌ Erro ao listar propriedades: {str(e)}")


# ==================== TESTE 3: REGISTRAR SESSÃO MANUALMENTE ====================
"""
Testa o registro manual de uma sessão no Notion
Use isso para confirmar que o envio está funcionando
"""

def teste_registrar_sessao():
    from dotenv import load_dotenv
    import os
    from notion_client import Client
    from datetime import datetime, timedelta
    
    load_dotenv()
    
    api_key = os.getenv("NOTION_API_KEY")
    database_id = os.getenv("DATABASE_ID")
    
    if not api_key or not database_id:
        print("❌ Configure .env primeiro")
        return
    
    try:
        client = Client(auth=api_key)
        
        # Simula uma sessão de 25 minutos
        agora = datetime.now()
        inicio = agora
        fim = agora + timedelta(minutes=25)
        
        payload = {
            "properties": {
                "Intervalo": {
                    "title": [{"text": {"content": "Teste de Conexão"}}]
                },
                "Inicio": {
                    "date": {"start": inicio.isoformat()}
                },
                "Fim": {
                    "date": {"start": fim.isoformat()}
                },
                "Tecnologia": {
                    "select": {"name": "Python"}
                }
            }
        }
        
        print("📤 Enviando sessão de teste para Notion...")
        
        response = client.pages.create(
            parent={"database_id": database_id},
            **payload
        )
        
        print("✅ Sessão registrada com sucesso!")
        print(f"   Page ID: {response['id']}")
        print(f"   Acesse no Notion para confirmar")
        
    except Exception as e:
        print(f"❌ Erro ao registrar: {str(e)}")


# ==================== TESTE 4: VALIDAR ESTRUTURA DO .ENV ====================
"""
Verifica se o .env está configurado corretamente
"""

def validar_env():
    import os
    from pathlib import Path
    
    env_path = Path(".env")
    
    print("🔍 Validando arquivo .env...")
    print()
    
    if not env_path.exists():
        print("❌ Arquivo .env não encontrado")
        print("   Execute: cp .env.example .env")
        return False
    
    print("✅ Arquivo .env encontrado")
    
    # Ler .env
    with open(env_path) as f:
        conteudo = f.read()
    
    # Verificar variáveis
    tem_api_key = "NOTION_API_KEY=" in conteudo
    tem_db_id = "DATABASE_ID=" in conteudo
    
    print()
    print("Variáveis presentes:")
    print(f"  ✓ NOTION_API_KEY" if tem_api_key else "  ✗ NOTION_API_KEY")
    print(f"  ✓ DATABASE_ID" if tem_db_id else "  ✗ DATABASE_ID")
    
    # Verificar se têm valores
    from dotenv import load_dotenv
    load_dotenv()
    
    api_key = os.getenv("NOTION_API_KEY", "").strip()
    db_id = os.getenv("DATABASE_ID", "").strip()
    
    print()
    print("Valores preenchidos:")
    print(f"  {'✓' if api_key else '✗'} NOTION_API_KEY: {len(api_key)} caracteres")
    print(f"  {'✓' if db_id else '✗'} DATABASE_ID: {len(db_id)} caracteres")
    
    print()
    if tem_api_key and tem_db_id and api_key and db_id:
        print("✅ .env está correto!")
        return True
    else:
        print("❌ .env incompleto ou com valores vazios")
        return False


# ==================== TESTE 5: VERIFICAR DEPENDÊNCIAS ====================
"""
Verifica se todas as bibliotecas necessárias estão instaladas
"""

def verificar_dependencias():
    print("🔍 Verificando dependências...")
    print()
    
    dependencias = [
        ("customtkinter", "Interface gráfica"),
        ("dotenv", "Variáveis de ambiente"),
        ("notion_client", "Cliente Notion"),
        ("httpx", "HTTP client"),
    ]
    
    tudo_ok = True
    
    for modulo, descricao in dependencias:
        try:
            __import__(modulo)
            print(f"  ✓ {modulo:<20} ({descricao})")
        except ImportError:
            print(f"  ✗ {modulo:<20} - NÃO INSTALADO")
            tudo_ok = False
    
    print()
    if tudo_ok:
        print("✅ Todas as dependências estão instaladas!")
    else:
        print("❌ Faltam dependências. Execute:")
        print("   pip install -r requirements.txt")
    
    return tudo_ok


# ==================== MENU DE TESTES ====================
"""
Menu interativo para executar testes
"""

def menu_testes():
    print()
    print("=" * 60)
    print("🧪 POMODORO DEV TRACKER - MENU DE TESTES")
    print("=" * 60)
    print()
    print("Testes disponíveis:")
    print("  1. Verificar dependências")
    print("  2. Validar arquivo .env")
    print("  3. Testar conexão com Notion")
    print("  4. Listar propriedades da database")
    print("  5. Registrar sessão de teste")
    print("  6. Executar todos os testes")
    print("  0. Sair")
    print()


# ==================== EXEMPLO DE USO ====================
"""
Exemplo de como usar a aplicação programaticamente
"""

def exemplo_uso():
    """
    Exemplo de como criar e usar a aplicação
    
    Nota: Este é um exemplo. Para usar a interface gráfica,
    execute: python main.py
    """
    
    from main import PomodoroTimer, NotionService
    from datetime import datetime, timedelta
    from dotenv import load_dotenv
    import os
    
    load_dotenv()
    
    print("📌 Exemplo de Uso Programático")
    print()
    
    # 1. Criar um timer
    print("1. Criando timer Pomodoro...")
    timer = PomodoroTimer()
    print(f"   Tempo inicial: {timer.obter_tempo_formatado()}")
    print()
    
    # 2. Simular uma sessão rápida
    print("2. Simulando sessão (reduzida para 5 segundos)...")
    timer.tempo_restante = 5  # 5 segundos para teste
    timer.iniciar()
    print(f"   Timer iniciado em: {timer.tempo_inicio}")
    
    # Decrementar alguns segundos
    for i in range(3):
        timer.decrementar()
        print(f"   Tempo restante: {timer.obter_tempo_formatado()}")
    
    timer.parar()
    print(f"   Timer finalizado em: {timer.tempo_fim}")
    print()
    
    # 3. Integração com Notion
    print("3. Testando integração com Notion...")
    api_key = os.getenv("NOTION_API_KEY")
    database_id = os.getenv("DATABASE_ID")
    
    if api_key and database_id:
        notion = NotionService(api_key, database_id)
        print(f"   Conectado: {notion.connected}")
    else:
        print("   ⚠️ Configure .env primeiro")
    
    print()
    print("✅ Exemplo concluído!")


# ==================== MAIN ====================
if __name__ == "__main__":
    import sys
    
    # Se executado com argumentos
    if len(sys.argv) > 1:
        comando = sys.argv[1].lower()
        
        if comando == "deps":
            verificar_dependencias()
        elif comando == "env":
            validar_env()
        elif comando == "notion":
            teste_conexao_notion()
        elif comando == "props":
            listar_propriedades_database()
        elif comando == "registro":
            teste_registrar_sessao()
        elif comando == "exemplo":
            exemplo_uso()
        elif comando == "all":
            verificar_dependencias()
            print()
            validar_env()
            print()
            teste_conexao_notion()
            print()
            listar_propriedades_database()
        else:
            print(f"Comando desconhecido: {comando}")
            print()
            print("Comandos disponíveis:")
            print("  python tests.py deps     - Verificar dependências")
            print("  python tests.py env      - Validar .env")
            print("  python tests.py notion   - Testar Notion")
            print("  python tests.py props    - Listar propriedades")
            print("  python tests.py registro - Registrar teste")
            print("  python tests.py exemplo  - Mostrar exemplo")
            print("  python tests.py all      - Executar todos")
    
    else:
        # Menu interativo
        while True:
            menu_testes()
            opcao = input("Escolha uma opção: ").strip()
            print()
            
            if opcao == "0":
                print("👋 Até logo!")
                break
            elif opcao == "1":
                verificar_dependencias()
            elif opcao == "2":
                validar_env()
            elif opcao == "3":
                teste_conexao_notion()
            elif opcao == "4":
                listar_propriedades_database()
            elif opcao == "5":
                teste_registrar_sessao()
            elif opcao == "6":
                verificar_dependencias()
                print()
                validar_env()
                print()
                teste_conexao_notion()
                print()
                listar_propriedades_database()
            else:
                print("❌ Opção inválida")
            
            input("\nPressione ENTER para continuar...")
            print()

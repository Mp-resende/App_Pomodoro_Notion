import urllib.request
import json
import sys

TOKEN = "SEU_TOKEN_DO_NOTION"
HEADERS = {
    "Authorization": "Bearer " + TOKEN,
    "Notion-Version": "2022-06-28",
    "Content-Type": "application/json"
}

def search_databases():
    url = "https://api.notion.com/v1/search"
    data = json.dumps({"filter": {"value": "database", "property": "object"}}).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST")
    try:
        with urllib.request.urlopen(req) as res:
            response = json.loads(res.read().decode("utf-8"))
            return response.get("results", [])
    except Exception as e:
        print("Erro na busca: " + str(e))
        return []

dbs = search_databases()
target_db = None
for db in dbs:
    title_obj = db.get("title", [])
    if title_obj:
        title = title_obj[0].get("plain_text", "").lower()
        if "intervalo" in title or "estudo" in title:
            target_db = db
            break

if not target_db:
    print("Tabela Intervalo de Estudos nao encontrada! Certifique-se de que ela foi compartilhada com a Integracao (no botao Share).")
    print("Databases encontradas:")
    for db in dbs:
        t_obj = db.get("title", [])
        if t_obj:
            print("- " + t_obj[0].get("plain_text", ""))
    sys.exit(0)

print("\n--- Tabela encontrada: " + target_db["title"][0]["plain_text"] + " ---")
print("Colunas disponiveis:")
properties = target_db.get("properties", {})
for prop_name, prop_info in properties.items():
    print("- " + prop_name + " (Tipo: " + prop_info.get("type") + ")")

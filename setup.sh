#!/bin/bash
# ==================== INSTALAÇÃO RÁPIDA DO POMODORO DEV TRACKER ====================
# Este script instala todas as dependências necessárias
# Uso: bash setup.sh

echo "🍅 Pomodoro Dev Tracker - Setup"
echo "================================"

# Verificar se Python está instalado
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 não está instalado. Por favor, instale Python 3.8 ou superior."
    exit 1
fi

echo "✓ Python detectado: $(python3 --version)"

# Criar ambiente virtual
echo ""
echo "📦 Criando ambiente virtual..."
python3 -m venv venv

# Ativar ambiente virtual
echo "🔓 Ativando ambiente virtual..."
source venv/bin/activate

# Atualizar pip
echo "🔄 Atualizando pip..."
pip install --upgrade pip

# Instalar dependências
echo "📥 Instalando dependências..."
pip install -r requirements.txt

echo ""
echo "✅ Setup concluído com sucesso!"
echo ""
echo "📝 Próximas etapas:"
echo "1. Copie .env.example para .env"
echo "2. Preencha as variáveis NOTION_API_KEY e DATABASE_ID"
echo "3. Execute: python main.py"
echo ""
echo "💡 Para desativar o ambiente virtual, execute: deactivate"

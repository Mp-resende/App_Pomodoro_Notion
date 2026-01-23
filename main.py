"""
Pomodoro Dev Tracker - Aplicativo de Foco com Integração Notion
Autor: Desenvolvedor Python Sênior
Descrição: Cronômetro Pomodoro com GUI em customtkinter e integração automática com Notion.
"""

import customtkinter as ctk
from customtkinter import CTkLabel, CTkButton, CTkEntry, CTkComboBox
from dotenv import load_dotenv
import os
import threading
from datetime import datetime
from notion_client import Client
from typing import Optional
import logging

# ==================== CONFIGURAÇÃO DE LOGGING ====================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ==================== CLASSE NOTION SERVICE ====================
class NotionService:
    """Serviço responsável pela integração com a API do Notion."""
    
    def __init__(self, api_key: str, database_id: str):
        """
        Inicializa o cliente Notion.
        
        Args:
            api_key (str): Chave de API do Notion
            database_id (str): ID da database do Notion
        """
        self.api_key = api_key
        self.database_id = database_id
        self.client = Client(auth=api_key)
        self.connected = False
        self._verify_connection()
    
    def _verify_connection(self) -> None:
        """Verifica se a conexão com o Notion foi estabelecida com sucesso."""
        try:
            self.client.databases.retrieve(database_id=self.database_id)
            self.connected = True
            logger.info("✓ Conectado com sucesso ao Notion")
        except Exception as e:
            self.connected = False
            logger.error(f"✗ Erro ao conectar ao Notion: {str(e)}")
    
    def registrar_sessao(self, intervalo: str, inicio: datetime, fim: datetime, tecnologia: str) -> bool:
        """
        Registra uma sessão de Pomodoro no Notion.
        
        Args:
            intervalo (str): Nome/descrição da tarefa
            inicio (datetime): Timestamp de início (ISO 8601)
            fim (datetime): Timestamp de término (ISO 8601)
            tecnologia (str): Categoria/tecnologia utilizada
        
        Returns:
            bool: True se o registro foi bem-sucedido, False caso contrário
        """
        if not self.connected:
            logger.error("Não há conexão com o Notion")
            return False
        
        try:
            payload = {
                "properties": {
                    "Intervalo": {
                        "title": [{"text": {"content": intervalo}}]
                    },
                    "Inicio": {
                        "date": {"start": inicio.isoformat()}
                    },
                    "Fim": {
                        "date": {"start": fim.isoformat()}
                    },
                    "Tecnologia": {
                        "select": {"name": tecnologia}
                    }
                }
            }
            
            response = self.client.pages.create(
                parent={"database_id": self.database_id},
                **payload
            )
            
            logger.info(f"✓ Sessão registrada no Notion: {intervalo}")
            return True
        
        except Exception as e:
            logger.error(f"✗ Erro ao registrar sessão no Notion: {str(e)}")
            return False


# ==================== CLASSE TIMER ====================
class PomodoroTimer:
    """Gerencia a lógica do timer Pomodoro."""
    
    TEMPO_PADRAO = 25 * 60  # 25 minutos em segundos
    
    def __init__(self):
        """Inicializa o timer."""
        self.tempo_restante = self.TEMPO_PADRAO
        self.rodando = False
        self.tempo_inicio: Optional[datetime] = None
        self.tempo_fim: Optional[datetime] = None
    
    def iniciar(self) -> None:
        """Inicia o timer e registra o tempo de início."""
        if not self.rodando:
            self.rodando = True
            self.tempo_inicio = datetime.now()
    
    def parar(self) -> None:
        """Para o timer e registra o tempo de término."""
        self.rodando = False
        self.tempo_fim = datetime.now()
    
    def resetar(self) -> None:
        """Reseta o timer para o valor padrão."""
        self.tempo_restante = self.TEMPO_PADRAO
        self.rodando = False
        self.tempo_inicio = None
        self.tempo_fim = None
    
    def decrementar(self) -> None:
        """Decrementa o tempo restante em 1 segundo."""
        if self.tempo_restante > 0:
            self.tempo_restante -= 1
        else:
            self.parar()
    
    def obter_tempo_formatado(self) -> str:
        """
        Retorna o tempo formatado em MM:SS.
        
        Returns:
            str: Tempo no formato "MM:SS"
        """
        minutos = self.tempo_restante // 60
        segundos = self.tempo_restante % 60
        return f"{minutos:02d}:{segundos:02d}"
    
    def esta_finalizado(self) -> bool:
        """
        Verifica se o timer chegou a zero.
        
        Returns:
            bool: True se o tempo restante é 0
        """
        return self.tempo_restante == 0


# ==================== CLASSE APLICATIVO PRINCIPAL ====================
class PomodoroApp(ctk.CTk):
    """Aplicativo principal do Pomodoro Dev Tracker."""
    
    def __init__(self):
        """Inicializa a aplicação principal."""
        super().__init__()
        
        # Configuração da janela
        self.title("Pomodoro Dev Tracker")
        self.geometry("500x650")
        self.resizable(False, False)
        
        # Tema Dark Mode
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")
        
        # Inicializa o timer
        self.timer = PomodoroTimer()
        
        # Inicializa o serviço Notion
        self.notion_service = self._inicializar_notion()
        
        # Flag para controlar o loop do timer
        self.atualizando_timer = True
        
        # Cria a interface
        self._criar_interface()
        
        # Inicia o loop de atualização do timer
        self._atualizar_timer()
    
    def _inicializar_notion(self) -> Optional[NotionService]:
        """
        Carrega as credenciais do Notion a partir do arquivo .env.
        
        Returns:
            NotionService ou None: Instância do serviço Notion ou None se falhar
        """
        load_dotenv()
        
        api_key = os.getenv("NOTION_API_KEY")
        database_id = os.getenv("DATABASE_ID")
        
        if not api_key or not database_id:
            logger.error(
                "✗ Erro: Variáveis de ambiente não encontradas!\n"
                "   Certifique-se de que o arquivo '.env' está na raiz do projeto"
                " com as seguintes variáveis:\n"
                "   - NOTION_API_KEY\n"
                "   - DATABASE_ID"
            )
            return None
        
        return NotionService(api_key, database_id)
    
    def _criar_interface(self) -> None:
        """Constrói a interface gráfica do aplicativo."""
        
        # ========== FRAME PRINCIPAL ==========
        main_frame = ctk.CTkFrame(self)
        main_frame.pack(padx=20, pady=20, fill="both", expand=True)
        
        # ========== TÍTULO ==========
        titulo = CTkLabel(
            main_frame,
            text="Pomodoro Dev Tracker",
            font=("Arial", 28, "bold"),
            text_color="#00BCD4"
        )
        titulo.pack(pady=(0, 30))
        
        # ========== CAMPO DE TAREFA ==========
        label_tarefa = CTkLabel(
            main_frame,
            text="O que vai codar hoje?",
            font=("Arial", 12, "bold")
        )
        label_tarefa.pack(anchor="w", pady=(0, 5))
        
        self.entry_tarefa = CTkEntry(
            main_frame,
            placeholder_text="Descreva sua tarefa...",
            height=40,
            font=("Arial", 12)
        )
        self.entry_tarefa.pack(fill="x", pady=(0, 20))
        
        # ========== SELETOR DE CATEGORIA ==========
        label_categoria = CTkLabel(
            main_frame,
            text="Tecnologia / Categoria:",
            font=("Arial", 12, "bold")
        )
        label_categoria.pack(anchor="w", pady=(0, 5))
        
        self.combo_categoria = CTkComboBox(
            main_frame,
            values=["Python", "C#", "SQL", "n8n", "Arquitetura", "Outros"],
            height=40,
            font=("Arial", 12),
            state="readonly"
        )
        self.combo_categoria.set("Python")  # Valor padrão
        self.combo_categoria.pack(fill="x", pady=(0, 30))
        
        # ========== DISPLAY DO TIMER ==========
        self.label_timer = CTkLabel(
            main_frame,
            text="25:00",
            font=("Arial", 72, "bold"),
            text_color="#00BCD4"
        )
        self.label_timer.pack(pady=30)
        
        # ========== LABEL DE STATUS ==========
        self.label_status = CTkLabel(
            main_frame,
            text="Pronto para começar",
            font=("Arial", 14),
            text_color="#4CAF50"
        )
        self.label_status.pack(pady=(0, 30))
        
        # ========== FRAME DE BOTÕES ==========
        button_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        button_frame.pack(fill="x", pady=20)
        
        self.btn_iniciar = CTkButton(
            button_frame,
            text="Iniciar",
            command=self._iniciar_timer,
            height=50,
            font=("Arial", 14, "bold"),
            fg_color="#4CAF50",
            hover_color="#45a049"
        )
        self.btn_iniciar.pack(side="left", padx=5, expand=True, fill="both")
        
        self.btn_resetar = CTkButton(
            button_frame,
            text="Resetar",
            command=self._resetar_timer,
            height=50,
            font=("Arial", 14, "bold"),
            fg_color="#F44336",
            hover_color="#da190b"
        )
        self.btn_resetar.pack(side="left", padx=5, expand=True, fill="both")
        
        # ========== FOOTER ==========
        footer = CTkLabel(
            main_frame,
            text="💻 Desenvolvido com foco e qualidade",
            font=("Arial", 10),
            text_color="#888888"
        )
        footer.pack(pady=(30, 0))
    
    def _iniciar_timer(self) -> None:
        """Inicia o timer Pomodoro."""
        
        # Validação: tarefa em branco
        tarefa = self.entry_tarefa.get().strip()
        if not tarefa:
            self.label_status.configure(text="Erro: Digite uma tarefa!", text_color="#F44336")
            logger.warning("Tentativa de iniciar timer sem tarefa")
            return
        
        # Se o timer não estiver rodando, inicia
        if not self.timer.rodando:
            self.timer.iniciar()
            self.btn_iniciar.configure(state="disabled", text="Em foco...")
            self.label_status.configure(text="Focado...", text_color="#FFD700")
            logger.info(f"Timer iniciado para a tarefa: {tarefa}")
        else:
            # Se já está rodando, pausa (comportamento opcional)
            self.timer.parar()
            self.btn_iniciar.configure(state="normal", text="Retomar")
            self.label_status.configure(text="Pausado", text_color="#FFA500")
    
    def _resetar_timer(self) -> None:
        """Reseta o timer e limpa os campos."""
        self.timer.resetar()
        self.label_timer.configure(text="25:00")
        self.label_status.configure(text="Pronto para começar", text_color="#4CAF50")
        self.btn_iniciar.configure(state="normal", text="Iniciar")
        self.entry_tarefa.delete(0, "end")
        self.combo_categoria.set("Python")
        logger.info("Timer resetado")
    
    def _atualizar_timer(self) -> None:
        """Atualiza o timer a cada segundo (loop de atualização)."""
        
        if self.timer.rodando:
            self.timer.decrementar()
            self.label_timer.configure(text=self.timer.obter_tempo_formatado())
            
            # Verifica se o timer finalizou
            if self.timer.esta_finalizado():
                self._finalizar_sessao()
        
        # Agenda a próxima atualização em 1000ms (1 segundo)
        self.after(1000, self._atualizar_timer)
    
    def _finalizar_sessao(self) -> None:
        """Finaliza a sessão e registra no Notion em uma thread separada."""
        
        tarefa = self.entry_tarefa.get().strip()
        categoria = self.combo_categoria.get()
        
        self.label_status.configure(text="Enviando...", text_color="#2196F3")
        self.btn_iniciar.configure(state="disabled", text="Iniciar")
        
        logger.info(f"Finalizando sessão: {tarefa} ({categoria})")
        
        # Inicia uma thread para registrar no Notion sem travar a GUI
        thread_envio = threading.Thread(
            target=self._registrar_no_notion,
            args=(tarefa, self.timer.tempo_inicio, self.timer.tempo_fim, categoria),
            daemon=True
        )
        thread_envio.start()
    
    def _registrar_no_notion(self, tarefa: str, inicio: datetime, fim: datetime, categoria: str) -> None:
        """
        Registra a sessão no Notion (executado em thread separada).
        
        Args:
            tarefa (str): Nome da tarefa
            inicio (datetime): Timestamp de início
            fim (datetime): Timestamp de término
            categoria (str): Categoria/tecnologia utilizada
        """
        
        if not self.notion_service or not self.notion_service.connected:
            self.label_status.configure(
                text="Erro: Notion não conectado",
                text_color="#F44336"
            )
            logger.error("Serviço Notion não disponível")
            self.btn_iniciar.configure(state="normal", text="Iniciar")
            return
        
        sucesso = self.notion_service.registrar_sessao(tarefa, inicio, fim, categoria)
        
        # Atualiza a interface com o resultado
        if sucesso:
            self.label_status.configure(text="✓ Sucesso!", text_color="#4CAF50")
            logger.info("Sessão registrada com sucesso no Notion")
        else:
            self.label_status.configure(text="✗ Erro ao enviar", text_color="#F44336")
            logger.error("Falha ao registrar sessão no Notion")
        
        self.btn_iniciar.configure(state="normal", text="Iniciar")
    
    def on_closing(self) -> None:
        """Executa limpeza quando a janela é fechada."""
        self.atualizando_timer = False
        self.destroy()


# ==================== FUNÇÃO MAIN ====================
def main() -> None:
    """Função principal que inicia a aplicação."""
    logger.info("Iniciando Pomodoro Dev Tracker...")
    app = PomodoroApp()
    app.protocol("WM_DELETE_WINDOW", app.on_closing)
    app.mainloop()


if __name__ == "__main__":
    main()

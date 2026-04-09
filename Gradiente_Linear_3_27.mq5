//+------------------------------------------------------------------+
//|                                   Gradiente Linear v3.27 VOLUMES |
//|                                  Copyright 2025, Trading Expert  |
//|         ✅ v3.27: VERIFICAÇÃO BOOK PÓS-RECONEXÃO                 |
//+------------------------------------------------------------------+

//Melhorias implementadas:
//v3.01: Identificação por TICKET (não por preço)
//v3.02: Ordem oposta calculada com PREÇO ORIGINAL
//v3.02: Tratamento de EXECUÇÕES PARCIAIS e COMPLETAS
//v3.03: DELAY configurável entre ordens
//v3.04: CSV OTIMIZADO-Salvo apenas em momentos críticos (OnDeinit, CriarGrade, ExecutarAcaoMeta, Botões manuais)
//v3.05: VERSÃO DEBUG: Logs completos em OnTradeTransaction
//v3.07: Compara dealVolume vs volumeOriginal
//v3.07: NÃO depende de OrderSelect!
//v3.07: Funciona em DEMO e REAL
//v3.08: Valida TamanhoLote >= Lote Mínimo
//v3.09: Delay ANTES de criar ordens (CORRIGIDO!)
//v3.10: Consolidação de ordens (mesmo tipo/preço)
//v3.10: Não reseta ticket (rastreabilidade)
//v3.11: OTIMIZAÇÃO - Atualiza apenas ordem que mudou (reduz 50% operações)
//v3.11: Compara ordem existente antes de cancelar/recriar
//v3.12: COMPARAÇÃO EXATA - Remove tolerâncias (mercado determinístico)
//v3.12: Consolidação usa igualdade exata de preço (não aproximada)
//v3.13: CANCELAMENTO SEGURO - Não tenta cancelar ordem já executada
//v3.13: Usa CancelarTodasOrdensDoEA() ao invés de OrderDelete direto
//v3.14: VALIDAÇÃO DE ÍNDICES - Calcula e cria ordens só se índice >= 0
//v3.14: Funciona com grades de um lado só (só BUY ou só SELL)
//v3.15: CORREÇÃO META - Bloqueia reativação automática após atingir meta
//v3.15: Desativa ANTES de fechar posições (evita ordem pendurada)
//v3.15: Duplo cancelamento para garantir limpeza completa
//v3.17: REMOVE PROTEÇÃO BOOK - Proteção era prejudicial (exec parciais/cascata são normais)
//v3.18: VERIFICAÇÃO ATIVA - Aguarda cancelamentos serem confirmados antes de criar novas ordens
//v3.18: Remove parâmetro DelayEntreOrdens (substituído por verificação ativa)
//v3.19: ATIVAR SEM CRIAR - Carrega CSV ao ativar sem criar (mapeia ordens existentes no book)
//v3.20: FIX LABEL MT5 - Deleta objeto antes de recriar (compatibilidade com update MT5)
//v3.21: NETTING SUPPORT - Meta/Prejuízo funciona em HEDGE (por MagicNumber) e NETTING (posição consolidada)
//v3.22: SINCRONIZAÇÃO INTELIGENTE - Usa HistoryDeals para reconstruir array após desconexão (OnTimer)
//v3.23: BREAK EVEN DINÂMICO - Quando lucro atinge X% do alvo, limite vira zero
//v3.23: TRAILING LOSS - A cada R$X de subida, lucro mínimo garantido sobe R$X
//v3.23: FIX SINCRONIZAÇÃO - Janela usa timestamp da desconexão (não última sync)
//v3.24: BREAK EVEN VALOR - Break Even dispara em valor fixo (R$) independente do lucro alvo
//v3.25: BACKUP CSV - Cria backup automático do CSV ao desativar EA
//v3.25: SYNC MELHORADA - Mostra claramente se sincronização rodou ou não
//v3.26: TICK SIZE - Arredonda preços para tick size do ativo (corrige J/K)
//v3.27: VERIFICAÇÃO BOOK - Após reconexão, verifica se ordens extremas existem e recria se necessário


#property copyright "Copyright 2025, Trading Expert"
#property version   "3.27"
#property strict

// Incluir bibliotecas necessárias
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enums para configuração                                          |
//+------------------------------------------------------------------+
enum ENUM_STATUS {
   STATUS_INATIVO = 0,  // Inativo
   STATUS_ATIVO   = 1   // Ativo
};

enum ENUM_PERSISTENCIA {
   PERSISTENCIA_MANTER = 0,          // Mantém tudo funcionando
   PERSISTENCIA_FECHAR_ORDENS = 1,   // Apenas fecha ordens
   PERSISTENCIA_FECHAR_TUDO = 2,     // Fecha ordens e posições
   PERSISTENCIA_DESATIVAR = 3        // Desativa mantendo ordens 
};

enum ENUM_ACAO_META {
   ACAO_FECHAR_E_DESATIVAR = 0,   // Fecha tudo e desativa
   ACAO_FECHAR_E_RECRIAR = 1      // Fecha tudo e recria grade
};

//+------------------------------------------------------------------+
//| Parâmetros de entrada                                            |
//+------------------------------------------------------------------+

input group "■■■Configurações Gerais de Grade| Dist_nova=Dist_anterior*(1+K)"
input double   KMultiplicadorAcima = 0.0;     // K para grade acima (0 = distância fixa)
input double   KMultiplicadorAbaixo = 0.0;    // K para grade abaixo (0 = distância fixa)

input group "■■■Configurações Gerais de Volume| Vol_novo=Vol_anterior*(1+J)"
input double   JMultiplicadorVolumeAcima = 0.0;   // J para volume acima (0 = fixo)
input double   JMultiplicadorVolumeAbaixo = 0.0;  // J para volume abaixo (0 = fixo)
input double   VolumeMaximo = 0;                  // Volume máximo (0 = sem limite)

input group "■■■ Grade Acima do Preço Atual "
input double   GapInicialAcima = 50;       // Gap inicial acima (Pips)
input double   DistanciaOrdensAcima = 20;  // Distância entre ordens acima (Pips)
input int      QtdOrdensAcima = 5;         // Quantidade de ordens acima
input bool     AtivarGradeAcima = true;    // Ativar grade acima

input group "■■■ Grade Abaixo do Preço Atual "
input double   GapInicialAbaixo = 50;       // Gap inicial abaixo (Pips)
input double   DistanciaOrdensAbaixo = 20;  // Distância entre ordens abaixo (Pips)
input int      QtdOrdensAbaixo = 5;         // Quantidade de ordens abaixo
input bool     AtivarGradeAbaixo = true;    // Ativar grade abaixo

input group "■■■ Configurações de Referência "
input double   PrecoReferencia = 0;  // Preço de Referência (0 = Preço Atual)

input group "■■■ Configurações de Volume e Gain "
input double   TamanhoLote = 1;    // Tamanho do lote
input double   GainPips = 100;     // Gain em Pips

input group "■■■ Configurações de Persistência "
input ENUM_PERSISTENCIA Persistencia = PERSISTENCIA_DESATIVAR;  // Tipo de persistência
input string   HorarioInicio = "09:00";      // Horário de início (HH:MM)
input bool     InicioAutomatico = true;      // Ativar início automático
input string   HorarioFechamento = "17:30";  // Horário de fechamento (HH:MM)

input group "■■■ Configurações de Persistência de Grade "
input bool     IniciarGradeAnterior = false;  // Iniciar com a grade anterior

input group "■■■ Configurações Técnicas "
input int      Slippage = 3;                  // Slippage (Pontos)
input int      MagicNumber = 12345;           // Número mágico
input bool     ModoBrasileiro = true;         // Ajustar para mercado brasileiro
input bool     ModoDebug = false;             // Modo debug
input ENUM_STATUS StatusInicial = STATUS_INATIVO;  // Status inicial

input group "■■■ Meta de Lucro/Prejuízo (Apenas HEDGE) "
input double   LucroAlvo = 0;              // Meta de lucro (R$) - 0 = desabilitado
input double   PrejuizoMaximo = 0;         // Limite de prejuízo (R$) - 0 = desabilitado
input ENUM_ACAO_META AcaoAoAtingirMeta = ACAO_FECHAR_E_DESATIVAR;  // Ação ao atingir meta

input group "■■■ Break Even e Trailing Loss "
input bool     UtilizarBreakEven = false;      // Utilizar Break Even?
input double   BreakEvenValor = 0;             // Break Even ativa em R$ (0 = desativado)
input bool     UtilizarTrailingLoss = false;   // Utilizar Trailing Loss?
input double   TrailingLossValor = 10.0;       // Trailing Loss: Incremento em R$

//+------------------------------------------------------------------+
//| ✅ ESTRUTURA: Com ticket único                                   |
//+------------------------------------------------------------------+
struct OriginalOrderInfo
{
   ulong ticket;              // Ticket único da ordem (0 = não enviada ao MT5)
   double originalPrice;      // Preço original da ordem
   double volume;             // Volume da ordem (PODE SER ATUALIZADO em parciais!)
   ENUM_ORDER_TYPE orderType; // Tipo da ordem
   string comment;            // Comentário da ordem
};

//+------------------------------------------------------------------+
//| Variáveis globais                                                |
//+------------------------------------------------------------------+
CTrade trade;
bool robotAtivo = false;
double pontoPorPip;
int digitosPips;
bool isHedge = false;

// ✅ v3.15: Flag para bloquear reativação automática após meta atingida
bool metaAtingidaHoje = false;
int diaUltimaVerificacao = -1;

// ✅ v3.21: Timestamp para reset do cálculo de lucro/prejuízo
// Quando a meta é atingida e a grade é recriada, só considera deals após este momento
datetime ultimoResetLucroPrejuizo = 0;

// ✅ v3.22: Controle de sincronização após reconexão
datetime ultimaSincronizacao = 0;
bool emDesconexao = false;
datetime timestampDesconexao = 0;  // ✅ v3.23: Momento exato da desconexão

// ✅ v3.22: Controle de Break Even e Trailing Loss dinâmico
double prejuizoDinamico = 0;          // Prejuízo dinâmico atual (começa = PrejuizoMaximo)
bool breakEvenAtivado = false;        // Flag: Break Even já foi ativado?
double nivelBaseTrailing = 0;         // Nível de lucro base para cálculo do Trailing

// Array para armazenar TODA a grade (memória)
OriginalOrderInfo originalOrders[];

// Variáveis para o painel de controle
int panelWidth = 230;
int panelHeight = 250;
int panelX = 0;
int panelY = 0;
color panelColor = clrWhiteSmoke;
color textColor = clrBlack;

//+------------------------------------------------------------------+
//| Funções auxiliares básicas                                       |
//+------------------------------------------------------------------+
double PipsParaPontos(double pips)
{
   return pips * pontoPorPip;
}

double PontosParaPips(double pontos)
{
   return pontos / pontoPorPip;
}

//+------------------------------------------------------------------+
//| ✅ v3.26: Arredondar preço para tick size do ativo               |
//+------------------------------------------------------------------+
double ArredondarPreco(double preco)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize > 0)
   {
      preco = MathRound(preco / tickSize) * tickSize;
   }

   return NormalizeDouble(preco, _Digits);
}

double ArredondarVolume(double volume)
{
   double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volumeMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   volume = MathRound(volume / volumeStep) * volumeStep;

   if(volume < volumeMin)
      volume = volumeMin;
   if(volumeMax > 0 && volume > volumeMax)
      volume = volumeMax;

   if(VolumeMaximo > 0 && volume > VolumeMaximo)
      volume = VolumeMaximo;

   volume = NormalizeDouble(volume, 2);

   return volume;
}

//+------------------------------------------------------------------+
//| ✅ v3.10: Adicionar ordem ao array (com consolidação)           |
//+------------------------------------------------------------------+
void AdicionarOrdemAoArray(ENUM_ORDER_TYPE tipo, double preco,
                           double volume, string comentario)
{
   if(ModoDebug)
      Print("📝 Adicionando ordem: ", EnumToString(tipo),
            " @ ", DoubleToString(preco, _Digits),
            " vol: ", DoubleToString(volume, 2));

   // ✅ v3.26: Arredondar preço para tick size
   preco = ArredondarPreco(preco);

   // Verificar se já existe ordem do mesmo tipo e preço
   bool encontrouDuplicada = false;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      // Verificar se é mesmo tipo
      if(originalOrders[i].orderType != tipo)
         continue;

      // Verificar se é EXATAMENTE o mesmo preço (sem tolerância)
      if(originalOrders[i].originalPrice == preco)
      {
         // ✅ CONSOLIDAR volumes
         double volumeAnterior = originalOrders[i].volume;
         originalOrders[i].volume += volume;
         originalOrders[i].volume = ArredondarVolume(originalOrders[i].volume);

         if(ModoDebug)
         {
            Print("🔄 ORDEM CONSOLIDADA!");
            Print("   Tipo: ", EnumToString(tipo));
            Print("   Preço: ", DoubleToString(preco, _Digits));
            Print("   Volume anterior: ", DoubleToString(volumeAnterior, 2));
            Print("   Volume adicionado: ", DoubleToString(volume, 2));
            Print("   Volume total: ", DoubleToString(originalOrders[i].volume, 2));
         }

         encontrouDuplicada = true;
         break;
      }
   }

   if(!encontrouDuplicada)
   {
      // ✅ ADICIONAR nova ordem
      int size = ArraySize(originalOrders);
      ArrayResize(originalOrders, size + 1);

      originalOrders[size].ticket = 0;
      originalOrders[size].originalPrice = preco;
      originalOrders[size].volume = ArredondarVolume(volume);
      originalOrders[size].orderType = tipo;
      originalOrders[size].comment = comentario;

      if(ModoDebug)
      {
         Print("✅ ORDEM ADICIONADA ao array");
         Print("   Índice: ", size);
         Print("   Tipo: ", EnumToString(tipo));
         Print("   Preço: ", DoubleToString(preco, _Digits));
         Print("   Volume: ", DoubleToString(originalOrders[size].volume, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| Buscar ordem no array por TICKET                                |
//+------------------------------------------------------------------+
int EncontrarOrdemPorTicket(ulong ticketProcurado)
{
   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].ticket == ticketProcurado)
      {
         if(ModoDebug)
            Print("✅ Ordem encontrada no array: índice ", i, ", ticket #", ticketProcurado);
         return i;
      }
   }

   if(ModoDebug)
      Print("⚠️ Ordem NÃO encontrada no array: ticket #", ticketProcurado);

   return -1; // Não encontrada
}

//+------------------------------------------------------------------+
//| ✅ v3.23: Buscar ordem no array por PREÇO e TIPO                 |
//+------------------------------------------------------------------+
int EncontrarOrdemPorPrecoETipo(double precoProcurado, ENUM_ORDER_TYPE tipoProcurado)
{
   double tolerancia = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].orderType == tipoProcurado)
      {
         if(MathAbs(originalOrders[i].originalPrice - precoProcurado) <= tolerancia)
         {
            if(ModoDebug)
               Print("✅ Ordem encontrada por preço/tipo: índice ", i,
                     ", preço ", DoubleToString(precoProcurado, _Digits));
            return i;
         }
      }
   }

   if(ModoDebug)
      Print("⚠️ Ordem NÃO encontrada por preço/tipo: ",
            DoubleToString(precoProcurado, _Digits), " ", EnumToString(tipoProcurado));

   return -1;
}

//+------------------------------------------------------------------+
//| Salvar estado da grade em CSV                                    |
//+------------------------------------------------------------------+
void SalvarEstadoGrade()
{
   if(ArraySize(originalOrders) == 0)
   {
      if(ModoDebug)
         Print("Array vazio, nada para salvar no CSV");
      return;
   }
   
   string nomeArquivo = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);
   
   int handle = FileOpen(nomeArquivo, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);
   
   if(handle == INVALID_HANDLE)
   {
      Print("Erro ao criar arquivo CSV: ", GetLastError());
      return;
   }
   
   // Cabeçalho com campo Ticket
   FileWriteString(handle, "Ticket,Tipo,Preco,Volume,Comentario\n");
   
   // Escrever TODAS as ordens do array
   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      string linha = StringFormat("%I64u,%d,%f,%f,%s\n",
                                   originalOrders[i].ticket,
                                   (int)originalOrders[i].orderType,
                                   originalOrders[i].originalPrice,
                                   originalOrders[i].volume,
                                   originalOrders[i].comment);
      FileWriteString(handle, linha);
   }
   
   FileClose(handle);

   if(ModoDebug)
      Print("✅ Grade salva em CSV com ", ArraySize(originalOrders), " ordens");
}

//+------------------------------------------------------------------+
//| ✅ v3.25: Criar backup do CSV com timestamp                      |
//+------------------------------------------------------------------+
void BackupCSV()
{
   string nomeArquivo = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

   if(!FileIsExist(nomeArquivo, FILE_COMMON))
   {
      if(ModoDebug)
         Print("❌ Nenhum CSV para fazer backup");
      return;
   }

   // Criar nome do backup com data/hora
   MqlDateTime tempo;
   TimeToStruct(TimeCurrent(), tempo);
   string nomeBackup = StringFormat("%s_%d_Grade_BKP_%04d%02d%02d_%02d%02d%02d.csv",
                                    _Symbol, MagicNumber,
                                    tempo.year, tempo.mon, tempo.day,
                                    tempo.hour, tempo.min, tempo.sec);

   // Copiar arquivo
   if(FileCopy(nomeArquivo, FILE_COMMON, nomeBackup, FILE_COMMON))
   {
      Print("💾 Backup do CSV criado: ", nomeBackup);
   }
   else
   {
      Print("❌ Erro ao criar backup do CSV: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Carregar grade anterior do CSV                                   |
//| ✅ v3.19: Parâmetro opcional para não criar ordens               |
//+------------------------------------------------------------------+
void CarregarGradeAnterior(bool criarOrdensNoMT5 = true)
{
   string nomeArquivo = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);
   
   if(!FileIsExist(nomeArquivo, FILE_COMMON))
   {
      if(ModoDebug)
         Print("❌ Arquivo CSV não encontrado: ", nomeArquivo);
      return;
   }
   
   int handle = FileOpen(nomeArquivo, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   
   if(handle == INVALID_HANDLE)
   {
      Print("❌ Erro ao abrir arquivo CSV: ", GetLastError());
      return;
   }
   
   if(ModoDebug)
      Print("📂 Carregando grade do CSV...");
   
   // Limpar array
   ArrayResize(originalOrders, 0);
   
   // Ignorar cabeçalho
   string cabecalho = FileReadString(handle);
   
   int contadorOrdens = 0;
   
   // Ler cada linha
   while(!FileIsEnding(handle))
   {
      string linha = FileReadString(handle);
      
      if(linha == "" || StringLen(linha) < 5)
         continue;
      
      // Separar valores por vírgula
      string valores[];
      StringSplit(linha, ',', valores);
      
      if(ArraySize(valores) < 5)
         continue;
      
      // Extrair informações incluindo TICKET
      ulong ticket = StringToInteger(valores[0]);
      ENUM_ORDER_TYPE tipo = (ENUM_ORDER_TYPE)StringToInteger(valores[1]);
      double preco = StringToDouble(valores[2]);
      double volume = StringToDouble(valores[3]);
      string comentario = valores[4];
      
      if(preco <= 0 || volume <= 0)
         continue;
      
      // Adicionar ao array
      int size = ArraySize(originalOrders);
      ArrayResize(originalOrders, size + 1);
      originalOrders[size].ticket = ticket;
      originalOrders[size].originalPrice = preco;
      originalOrders[size].volume = volume;
      originalOrders[size].orderType = tipo;
      originalOrders[size].comment = comentario;
      
      contadorOrdens++;
   }
   
   FileClose(handle);
   
   if(ModoDebug)
      Print("✅ Grade carregada: ", contadorOrdens, " ordens");

   // ✅ v3.19: Só cria ordens se solicitado
   if(criarOrdensNoMT5)
      InserirOrdensExtremas();
}

//+------------------------------------------------------------------+
//| Criar grade inicial completa                                     |
//+------------------------------------------------------------------+
void CriarGradeInicialCompleta()
{
   // Determinar preço de referência
   double precoAtual = (PrecoReferencia > 0) ? PrecoReferencia : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(ModoDebug)
      Print("🔧 Criando grade inicial com referência: ", DoubleToString(precoAtual, _Digits));
   
   // Limpar array
   ArrayResize(originalOrders, 0);
   
   // ===== CRIAR BUYs (ABAIXO DO PREÇO) =====
   if(AtivarGradeAbaixo)
   {
      double volumeAtual = TamanhoLote;
      
      for(int i = 0; i < QtdOrdensAbaixo; i++)
      {
         // Calcular soma das distâncias crescentes
         double somaDistancias = 0;
         double dist = DistanciaOrdensAbaixo;
         
         for(int j = 0; j < i; j++)
         {
            somaDistancias += MathRound(dist);
            dist = dist + (dist * KMultiplicadorAbaixo);
         }
         
         double preco = ArredondarPreco(precoAtual - (GapInicialAbaixo + somaDistancias) * pontoPorPip);
         double volumeOrdem = ArredondarVolume(volumeAtual);

         // Adicionar ao array (SEM criar no MT5)
         int size = ArraySize(originalOrders);
         ArrayResize(originalOrders, size + 1);
         originalOrders[size].ticket = 0;
         originalOrders[size].originalPrice = preco;
         originalOrders[size].volume = volumeOrdem;
         originalOrders[size].orderType = ORDER_TYPE_BUY_LIMIT;
         originalOrders[size].comment = "Grade Inicial";
         
         if(ModoDebug)
            Print("  BUY adicionada: ", DoubleToString(preco, _Digits), " vol: ", volumeOrdem);
         
         // Calcular próximo volume
         volumeAtual = volumeAtual * (1.0 + JMultiplicadorVolumeAbaixo);
      }
   }
   
   // ===== CRIAR SELLs (ACIMA DO PREÇO) =====
   if(AtivarGradeAcima)
   {
      double volumeAtual = TamanhoLote;
      
      for(int i = 0; i < QtdOrdensAcima; i++)
      {
         // Calcular soma das distâncias crescentes
         double somaDistancias = 0;
         double dist = DistanciaOrdensAcima;
         
         for(int j = 0; j < i; j++)
         {
            somaDistancias += MathRound(dist);
            dist = dist + (dist * KMultiplicadorAcima);
         }
         
         double preco = ArredondarPreco(precoAtual + (GapInicialAcima + somaDistancias) * pontoPorPip);
         double volumeOrdem = ArredondarVolume(volumeAtual);

         // Adicionar ao array (SEM criar no MT5)
         int size = ArraySize(originalOrders);
         ArrayResize(originalOrders, size + 1);
         originalOrders[size].ticket = 0;
         originalOrders[size].originalPrice = preco;
         originalOrders[size].volume = volumeOrdem;
         originalOrders[size].orderType = ORDER_TYPE_SELL_LIMIT;
         originalOrders[size].comment = "Grade Inicial";
         
         if(ModoDebug)
            Print("  SELL adicionada: ", DoubleToString(preco, _Digits), " vol: ", volumeOrdem);
         
         // Calcular próximo volume
         volumeAtual = volumeAtual * (1.0 + JMultiplicadorVolumeAcima);
      }
   }
   
   if(ModoDebug)
      Print("✅ Grade criada com ", ArraySize(originalOrders), " ordens");
   
   // Salvar CSV
   SalvarEstadoGrade();
   
   // Inserir as 2 extremas no MT5
   InserirOrdensExtremas();
}

//+------------------------------------------------------------------+
//| Inserir ordens extremas no book - OTIMIZADO v3.11                |
//| Cria apenas ordens que realmente precisam ser atualizadas        |
//+------------------------------------------------------------------+
void InserirOrdensExtremas()
{
   if(ModoDebug)
      Print("🔄 Atualizando ordens extremas no book...");

   // ===== PASSO 1: Calcular as 2 extremas que DEVERIAM existir =====

   int indiceMaiorBuy = -1;
   double maiorPrecoBuy = 0;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].orderType == ORDER_TYPE_BUY_LIMIT)
      {
         if(originalOrders[i].originalPrice > maiorPrecoBuy)
         {
            maiorPrecoBuy = originalOrders[i].originalPrice;
            indiceMaiorBuy = i;
         }
      }
   }

   int indiceMenorSell = -1;
   double menorPrecoSell = DBL_MAX;

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      if(originalOrders[i].orderType == ORDER_TYPE_SELL_LIMIT)
      {
         if(originalOrders[i].originalPrice < menorPrecoSell)
         {
            menorPrecoSell = originalOrders[i].originalPrice;
            indiceMenorSell = i;
         }
      }
   }

   // ===== ✅ VALIDAÇÃO: Verificar se array está totalmente vazio =====
   if(indiceMaiorBuy < 0 && indiceMenorSell < 0)
   {
      Print("========================================");
      Print("⚠️ AVISO: Array vazio!");
      Print("Toda a grade e ordens de retorno foram executadas.");
      Print("EA aguardando novas instruções.");
      Print("========================================");
      return;  // Sair com segurança
   }

   // ===== Calcular preços apenas para as extremas que EXISTEM =====
   double precoDeveriaBuy = 0;
   double volumeDeveriaBuy = 0;
   double precoDeveriaSell = 0;
   double volumeDeveriaSell = 0;

   if(indiceMaiorBuy >= 0)
   {
      precoDeveriaBuy = ArredondarPreco(originalOrders[indiceMaiorBuy].originalPrice);
      volumeDeveriaBuy = ArredondarVolume(originalOrders[indiceMaiorBuy].volume);
   }

   if(indiceMenorSell >= 0)
   {
      precoDeveriaSell = ArredondarPreco(originalOrders[indiceMenorSell].originalPrice);
      volumeDeveriaSell = ArredondarVolume(originalOrders[indiceMenorSell].volume);
   }

   // ===== PASSO 2: Ler a ordem que está no book (só tem 1 após execução!) =====

   ulong ticketExistente = 0;
   ENUM_ORDER_TYPE tipoExistente = ORDER_TYPE_BUY_LIMIT;  // Apenas para evitar warning compilador (só usada se encontrouOrdem=true)
   double precoExistente = 0;
   double volumeExistente = 0;
   bool encontrouOrdem = false;  // IMPORTANTE: tipoExistente só é válida se esta flag for true

   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         {
            ticketExistente = ticket;
            tipoExistente = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            precoExistente = NormalizeDouble(OrderGetDouble(ORDER_PRICE_OPEN), _Digits);
            volumeExistente = OrderGetDouble(ORDER_VOLUME_CURRENT);
            encontrouOrdem = true;

            if(ModoDebug)
               Print("📋 Ordem no book: ", EnumToString(tipoExistente),
                     " @ ", precoExistente, " vol: ", volumeExistente, " #", ticket);

            break; // Só tem 1 ordem após execução, pode sair
         }
      }
   }

   // ===== PASSO 3: Verificar se coincide com uma das calculadas =====

   bool coincideComBuy = false;
   bool coincideComSell = false;

   if(encontrouOrdem)
   {
      if(tipoExistente == ORDER_TYPE_BUY_LIMIT)
      {
         // Comparar EXATAMENTE com a BUY que deveria existir (sem tolerância)
         if(precoExistente == precoDeveriaBuy && volumeExistente == volumeDeveriaBuy)
         {
            coincideComBuy = true;

            if(ModoDebug)
               Print("✅ BUY do book coincide EXATAMENTE com a BUY calculada!");
         }
      }
      else if(tipoExistente == ORDER_TYPE_SELL_LIMIT)
      {
         // Comparar EXATAMENTE com a SELL que deveria existir (sem tolerância)
         if(precoExistente == precoDeveriaSell && volumeExistente == volumeDeveriaSell)
         {
            coincideComSell = true;

            if(ModoDebug)
               Print("✅ SELL do book coincide EXATAMENTE com a SELL calculada!");
         }
      }
   }

   // ===== PASSO 4: Decisão - Criar só 1 ou criar 2? =====

   // CASO A: Coincide → Criar SÓ a que falta
   if(coincideComBuy || coincideComSell)
   {
      if(ModoDebug)
         Print("🔄 Ordem do book está correta. Criando apenas a que falta...");

      // Se BUY coincide → criar só SELL (se existir no array)
      if(coincideComBuy && indiceMenorSell >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, volumeDeveriaSell, 0,
                            precoDeveriaSell, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[indiceMenorSell].comment))
         {
            ulong ticketCriado = trade.ResultOrder();
            originalOrders[indiceMenorSell].ticket = ticketCriado;

            if(ModoDebug)
               Print("  ✅ SELL criada: ", precoDeveriaSell, " vol: ", volumeDeveriaSell, " #", ticketCriado);
         }
         else
         {
            Print("  ❌ Erro ao criar SELL: ", trade.ResultRetcode());
         }
      }
      // Se SELL coincide → criar só BUY (se existir no array)
      else if(coincideComSell && indiceMaiorBuy >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, volumeDeveriaBuy, 0,
                            precoDeveriaBuy, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[indiceMaiorBuy].comment))
         {
            ulong ticketCriado = trade.ResultOrder();
            originalOrders[indiceMaiorBuy].ticket = ticketCriado;

            if(ModoDebug)
               Print("  ✅ BUY criada: ", precoDeveriaBuy, " vol: ", volumeDeveriaBuy, " #", ticketCriado);
         }
         else
         {
            Print("  ❌ Erro ao criar BUY: ", trade.ResultRetcode());
         }
      }
   }
   // CASO B: NÃO coincide → Cancelar TUDO + Criar as que existem no array
   else
   {
      if(ModoDebug)
         Print("🔄 Ordem do book NÃO coincide. Cancelando TODAS e recriando...");

      // Cancelar TODAS as ordens do EA
      CancelarTodasOrdensDoEA();

      // ✅ v3.18: Aguardar até ordens serem efetivamente canceladas (máx 1 segundo)
      int tentativas = 0;
      while(ContarOrdensDoEA() > 0 && tentativas < 20)
      {
         Sleep(50);
         tentativas++;
      }

      if(ModoDebug && tentativas > 0)
         Print("  ⏱️ Aguardou ", tentativas * 50, "ms para cancelamentos");

      // Criar BUY (só se existir no array)
      if(indiceMaiorBuy >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, volumeDeveriaBuy, 0,
                            precoDeveriaBuy, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[indiceMaiorBuy].comment))
         {
            ulong ticketCriado = trade.ResultOrder();
            originalOrders[indiceMaiorBuy].ticket = ticketCriado;

            if(ModoDebug)
               Print("  ✅ BUY criada: ", precoDeveriaBuy, " vol: ", volumeDeveriaBuy, " #", ticketCriado);
         }
         else
         {
            Print("  ❌ Erro ao criar BUY: ", trade.ResultRetcode());
         }
      }

      // Criar SELL (só se existir no array)
      if(indiceMenorSell >= 0)
      {
         trade.SetTypeFilling(ORDER_FILLING_RETURN);

         if(trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, volumeDeveriaSell, 0,
                            precoDeveriaSell, 0, 0, ORDER_TIME_GTC, 0,
                            originalOrders[indiceMenorSell].comment))
         {
            ulong ticketCriado = trade.ResultOrder();
            originalOrders[indiceMenorSell].ticket = ticketCriado;

            if(ModoDebug)
               Print("  ✅ SELL criada: ", precoDeveriaSell, " vol: ", volumeDeveriaSell, " #", ticketCriado);
         }
         else
         {
            Print("  ❌ Erro ao criar SELL: ", trade.ResultRetcode());
         }
      }
   }

   if(ModoDebug)
      Print("✅ Atualização concluída");
}

//+------------------------------------------------------------------+
//| Cancelar todas ordens do EA no MT5                               |
//+------------------------------------------------------------------+
void CancelarTodasOrdensDoEA()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         {
            trade.OrderDelete(ticket);

            if(ModoDebug)
               Print("  Ordem #", ticket, " cancelada");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ✅ v3.18: Contar ordens do EA no book                            |
//+------------------------------------------------------------------+
int ContarOrdensDoEA()
{
   int contador = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         {
            contador++;
         }
      }
   }

   return contador;
}

//+------------------------------------------------------------------+
//| Remover ordem do array por TICKET                                |
//+------------------------------------------------------------------+
void RemoverOrdemPorTicket(ulong ticketRemover)
{
   int indice = EncontrarOrdemPorTicket(ticketRemover);
   
   if(indice < 0)
   {
      if(ModoDebug)
         Print("⚠️ Ticket #", ticketRemover, " não encontrado para remoção");
      return;
   }
   
   if(ModoDebug)
      Print("🗑️ Removendo ordem do array: ticket #", ticketRemover, 
            " preço: ", DoubleToString(originalOrders[indice].originalPrice, _Digits));
   
   // Mover todas para trás
   for(int j = indice; j < ArraySize(originalOrders) - 1; j++)
   {
      originalOrders[j] = originalOrders[j + 1];
   }
   
   // Redimensionar array
   ArrayResize(originalOrders, ArraySize(originalOrders) - 1);
}

//+------------------------------------------------------------------+
//| Cancelar ordens pendentes                                        |
//+------------------------------------------------------------------+
void CancelarOrdensPendentes()
{
   Sleep(200);
   
   ulong tickets[];
   ArrayResize(tickets, 0);
   
   // Coletar tickets
   int total = OrdersTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0)
         continue;
         
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         int size = ArraySize(tickets);
         ArrayResize(tickets, size + 1);
         tickets[size] = ticket;
      }
   }
   
   if(ModoDebug)
      Print("Cancelando ", ArraySize(tickets), " ordens pendentes");
   
   // Cancelar ordens
   for(int i = 0; i < ArraySize(tickets); i++)
   {
      if(!OrderSelect(tickets[i]))
         continue;
      
      bool sucesso = false;
      for(int tentativa = 1; tentativa <= 3 && !sucesso; tentativa++)
      {
         if(trade.OrderDelete(tickets[i]))
         {
            sucesso = true;
            if(ModoDebug)
               Print("Ordem #", tickets[i], " cancelada");
         }
         else
         {
            Sleep(100);
         }
      }
      
      Sleep(100);
   }
   
   if(ModoDebug)
      Print("✅ Cancelamento concluído");
}

//+------------------------------------------------------------------+
//| Fechar todas as posições                                         |
//+------------------------------------------------------------------+
void FecharPosicoes()
{
   int total = PositionsTotal();
   
   Print("Fechando posições. Total: ", total);
   
   ulong tickets[];
   ArrayResize(tickets, 0);
   
   // Coletar tickets
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket <= 0)
         continue;
         
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         int size = ArraySize(tickets);
         ArrayResize(tickets, size + 1);
         tickets[size] = ticket;
      }
   }
   
   // Fechar posições
   for(int i = 0; i < ArraySize(tickets); i++)
   {
      if(!PositionSelectByTicket(tickets[i]))
         continue;
         
      bool sucesso = false;
      for(int tentativa = 1; tentativa <= 3 && !sucesso; tentativa++)
      {
         if(trade.PositionClose(tickets[i]))
         {
            sucesso = true;
            Print("Posição #", tickets[i], " fechada");
         }
         else
         {
            Sleep(200);
         }
      }
      
      Sleep(200);
   }
   
   Print("✅ Fechamento de posições concluído");
}

//+------------------------------------------------------------------+
//| Obter lucro/prejuízo total (HEDGE e NETTING)                      |
//| Inclui: Lucro flutuante + Lucro de operações fechadas do dia      |
//+------------------------------------------------------------------+
double ObterLucroPrejuizoTotal()
{
   double lucroFlutuante = 0;
   double lucroFechadas = 0;

   // ========== PARTE 1: LUCRO FLUTUANTE (posições abertas) ==========
   if(isHedge)
   {
      // HEDGE: Filtra por MagicNumber (múltiplos EAs podem rodar no mesmo símbolo)
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
               double profit = PositionGetDouble(POSITION_PROFIT);
               double swap = PositionGetDouble(POSITION_SWAP);

               lucroFlutuante += (profit + swap);

               if(ModoDebug)
                  Print("Posição #", ticket, ": Profit=", DoubleToString(profit, 2),
                        ", Swap=", DoubleToString(swap, 2));
            }
         }
      }
   }
   else
   {
      // NETTING: Pega lucro da posição consolidada do símbolo
      if(PositionSelect(_Symbol))
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         double swap = PositionGetDouble(POSITION_SWAP);

         lucroFlutuante = profit + swap;

         if(ModoDebug)
            Print("Posição NETTING flutuante: Profit=", DoubleToString(profit, 2),
                  ", Swap=", DoubleToString(swap, 2));
      }
   }

   // ========== PARTE 2: LUCRO OPERAÇÕES FECHADAS DO DIA ==========
   MqlDateTime tempoAtual;
   TimeCurrent(tempoAtual);

   // Início do dia atual
   MqlDateTime inicioDia;
   inicioDia.year = tempoAtual.year;
   inicioDia.mon = tempoAtual.mon;
   inicioDia.day = tempoAtual.day;
   inicioDia.hour = 0;
   inicioDia.min = 0;
   inicioDia.sec = 0;

   datetime dataInicioDia = StructToTime(inicioDia);
   datetime dataFim = TimeCurrent() + 3600; // Margem de 1 hora

   // ✅ v3.21: Se houve reset de lucro/prejuízo hoje, usar esse timestamp
   // Isso permite que "Fecha e recria grade" zere o contador
   datetime dataInicio = dataInicioDia;
   if(ultimoResetLucroPrejuizo > dataInicioDia)
   {
      dataInicio = ultimoResetLucroPrejuizo;
      if(ModoDebug)
         Print("Usando timestamp de reset: ", TimeToString(dataInicio));
   }

   // Carregar histórico de deals do dia
   if(HistorySelect(dataInicio, dataFim))
   {
      int totalDeals = HistoryDealsTotal();

      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket > 0)
         {
            string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);

            // Verificar se é do símbolo correto
            if(dealSymbol != _Symbol)
               continue;

            // Em HEDGE, filtrar também por MagicNumber
            if(isHedge)
            {
               long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
               if(dealMagic != MagicNumber)
                  continue;
            }

            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

            // Capturar lucro apenas de operações de saída (fechamento)
            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
               double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
               double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

               lucroFechadas += (dealProfit + dealSwap + dealCommission);

               if(ModoDebug)
                  Print("Deal #", dealTicket, " (fechado): Profit=", DoubleToString(dealProfit, 2),
                        ", Swap=", DoubleToString(dealSwap, 2),
                        ", Commission=", DoubleToString(dealCommission, 2));
            }
         }
      }
   }

   double lucroTotal = lucroFlutuante + lucroFechadas;

   if(ModoDebug)
      Print("Lucro Total (", (isHedge ? "HEDGE" : "NETTING"), "): Flutuante=",
            DoubleToString(lucroFlutuante, 2), " + Fechadas=", DoubleToString(lucroFechadas, 2),
            " = ", DoubleToString(lucroTotal, 2));

   return lucroTotal;
}

//+------------------------------------------------------------------+
//| Verificar meta de lucro/prejuízo                                 |
//+------------------------------------------------------------------+
void VerificarMetaLucroPrejuizo()
{
   // Funciona tanto em HEDGE quanto NETTING
   if(LucroAlvo <= 0 && PrejuizoMaximo >= 0)
      return;

   double lucroPrejuizoAtual = ObterLucroPrejuizoTotal();

   // ========== VERIFICAÇÃO DE LUCRO ==========
   if(LucroAlvo > 0 && lucroPrejuizoAtual >= LucroAlvo)
   {
      Print("========================================");
      Print("🎯 META DE LUCRO ATINGIDA!");
      Print("Lucro atual: R$ ", DoubleToString(lucroPrejuizoAtual, 2));
      Print("Meta configurada: R$ ", DoubleToString(LucroAlvo, 2));
      Print("========================================");

      ExecutarAcaoMeta();
      return;
   }

   // ========== ✅ v3.24: BREAK EVEN POR VALOR ==========
   // Quando lucro atinge valor fixo em R$, prejuízo é reconfigurado para zero
   if(UtilizarBreakEven && !breakEvenAtivado && BreakEvenValor > 0 && PrejuizoMaximo < 0)
   {
      if(lucroPrejuizoAtual >= BreakEvenValor)
      {
         breakEvenAtivado = true;
         prejuizoDinamico = 0;  // Prejuízo zerado!
         nivelBaseTrailing = lucroPrejuizoAtual;  // Base para trailing

         Print("========================================");
         Print("🔒 BREAK EVEN ATIVADO!");
         Print("Lucro atual: R$ ", DoubleToString(lucroPrejuizoAtual, 2));
         Print("Nível de ativação: R$ ", DoubleToString(BreakEvenValor, 2));
         Print("Prejuízo dinâmico: R$ ", DoubleToString(prejuizoDinamico, 2), " (era R$ ", DoubleToString(PrejuizoMaximo, 2), ")");
         Print("========================================");
      }
   }

   // ========== ✅ v3.22: TRAILING LOSS DINÂMICO ==========
   // A cada R$X de subida de lucro, prejuízo aumenta R$X
   if(UtilizarTrailingLoss && breakEvenAtivado && TrailingLossValor > 0)
   {
      double ganhoDesdeBreakEven = lucroPrejuizoAtual - nivelBaseTrailing;

      if(ganhoDesdeBreakEven > 0)
      {
         // Calcula quantos "degraus" de trailing já subimos
         int degrausTrailing = (int)MathFloor(ganhoDesdeBreakEven / TrailingLossValor);
         double novoPrejuizoDinamico = degrausTrailing * TrailingLossValor;

         // Só atualiza se subiu (nunca desce)
         if(novoPrejuizoDinamico > prejuizoDinamico)
         {
            double prejuizoAnterior = prejuizoDinamico;
            prejuizoDinamico = novoPrejuizoDinamico;

            Print("📈 TRAILING LOSS ATUALIZADO!");
            Print("Lucro atual: R$ ", DoubleToString(lucroPrejuizoAtual, 2));
            Print("Ganho desde Break Even: R$ ", DoubleToString(ganhoDesdeBreakEven, 2));
            Print("Prejuízo dinâmico: R$ ", DoubleToString(prejuizoAnterior, 2), " -> R$ ", DoubleToString(prejuizoDinamico, 2));
         }
      }
   }

   // ========== VERIFICAÇÃO DE PREJUÍZO ==========
   // ✅ v3.22: Lógica corrigida para Break Even e Trailing Loss
   // - Sem Break Even: encerra se lucro <= PrejuizoMaximo (negativo, ex: -50)
   // - Com Break Even: encerra se lucro <= prejuizoDinamico (positivo = lucro garantido!)

   if(breakEvenAtivado)
   {
      // Com Break Even ativo, prejuizoDinamico é o LUCRO MÍNIMO garantido
      if(lucroPrejuizoAtual <= prejuizoDinamico)
      {
         Print("========================================");
         Print("🔒 LUCRO MÍNIMO GARANTIDO ATINGIDO!");
         Print("Lucro atual: R$ ", DoubleToString(lucroPrejuizoAtual, 2));
         Print("Lucro mínimo garantido: R$ ", DoubleToString(prejuizoDinamico, 2));
         Print("(Prejuízo original era: R$ ", DoubleToString(PrejuizoMaximo, 2), ")");
         Print("========================================");

         ExecutarAcaoMeta();
         return;
      }
   }
   else
   {
      // Sem Break Even, usa o prejuízo máximo original
      if(PrejuizoMaximo < 0 && lucroPrejuizoAtual <= PrejuizoMaximo)
      {
         Print("========================================");
         Print("⚠️ LIMITE DE PREJUÍZO ATINGIDO!");
         Print("Prejuízo atual: R$ ", DoubleToString(lucroPrejuizoAtual, 2));
         Print("Limite configurado: R$ ", DoubleToString(PrejuizoMaximo, 2));
         Print("========================================");

         ExecutarAcaoMeta();
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Executar ação ao atingir meta                                    |
//+------------------------------------------------------------------+
void ExecutarAcaoMeta()
{
   Print("Executando ação: ", EnumToString(AcaoAoAtingirMeta));

   // ✅ v3.15: DESATIVAR PRIMEIRO para evitar que OnTradeTransaction crie novas ordens
   if(AcaoAoAtingirMeta == ACAO_FECHAR_E_DESATIVAR)
   {
      robotAtivo = false;
      metaAtingidaHoje = true;  // ✅ v3.15: Bloquear reativação automática
      AtualizarStatusVisual();

      if(ModoDebug)
         Print("🛑 Robô desativado ANTES de fechar posições/ordens");
   }

   Print("Cancelando todas as ordens pendentes (1ª passada)...");
   CancelarTodasOrdensDoEA();  // ✅ v3.15: Usar função mais direta
   Sleep(300);

   Print("Fechando todas as posições...");
   FecharPosicoes();
   Sleep(500);

   Print("Cancelando todas as ordens pendentes (2ª passada)...");
   CancelarTodasOrdensDoEA();  // ✅ v3.15: Duplo cancelamento para garantir
   Sleep(300);

   // ✅ v3.15: Terceira passada de segurança
   int ordensRestantes = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == MagicNumber)
      {
         ordensRestantes++;
      }
   }

   if(ordensRestantes > 0)
   {
      Print("⚠️ Ainda restam ", ordensRestantes, " ordens. Executando 3ª passada...");
      CancelarOrdensPendentes();
      Sleep(500);
   }

   if(AcaoAoAtingirMeta == ACAO_FECHAR_E_DESATIVAR)
   {
      SalvarEstadoGrade();

      Print("✅ EA DESATIVADO");
      Print("🚫 Reativação automática BLOQUEADA para hoje");
      if(InicioAutomatico)
         Print("Será reativado apenas no PRÓXIMO DIA às ", HorarioInicio);
      else
         Print("Para reativar, clique em 'Iniciar Operações'");
   }
   else if(AcaoAoAtingirMeta == ACAO_FECHAR_E_RECRIAR)
   {
      // ✅ v3.21: Resetar timestamp para zerar cálculo de lucro/prejuízo
      // Isso faz o EA ignorar deals anteriores a este momento
      ultimoResetLucroPrejuizo = TimeCurrent();
      Print("📊 Lucro/Prejuízo resetado. Novo período inicia em: ", TimeToString(ultimoResetLucroPrejuizo));

      // ✅ v3.22: Resetar variáveis de Break Even e Trailing Loss
      breakEvenAtivado = false;
      prejuizoDinamico = 0;
      nivelBaseTrailing = 0;
      Print("🔄 Break Even e Trailing Loss resetados para nova grade");

      Print("Criando nova grade...");
      Sleep(1000);
      CriarGradeInicialCompleta();

      Print("✅ NOVA GRADE CRIADA");
      Print("EA continua ativo e operando");
   }

   Print("========================================");
}

//+------------------------------------------------------------------+
//| ✅ v3.23: SINCRONIZAÇÃO COM SERVIDOR após reconexão              |
//| Fluxo: Analisa deals → Conserta array → Salva CSV → Cancela      |
//|        ordens → Reinicia com grade anterior                      |
//+------------------------------------------------------------------+
void SincronizarComServidor()
{
   Print("========================================");
   Print("🔄 INICIANDO SINCRONIZAÇÃO COM SERVIDOR");
   Print("========================================");

   // ✅ v3.23: Usar timestamp da desconexão como início da janela
   datetime inicioJanela = timestampDesconexao;

   if(inicioJanela == 0)
   {
      Print("⚠️ Timestamp de desconexão não definido - usando 1 hora atrás");
      inicioJanela = TimeCurrent() - 3600;
   }

   datetime agora = TimeCurrent();

   Print("🕐 Janela de sincronização:");
   Print("   De: ", TimeToString(inicioJanela, TIME_DATE|TIME_SECONDS));
   Print("   Até: ", TimeToString(agora, TIME_DATE|TIME_SECONDS));

   if(!HistorySelect(inicioJanela, agora))
   {
      Print("❌ Erro ao carregar histórico de deals: ", GetLastError());
      return;
   }

   // ========== PASSO 1: COLETAR DEALS DO PERÍODO ==========
   double volumeBuyTotal = 0;
   double volumeSellTotal = 0;
   double precoBuyExec = 0;
   double precoSellExec = 0;
   double volumeBuyOriginal = 0;
   double volumeSellOriginal = 0;
   int indiceBuy = -1;
   int indiceSell = -1;

   int totalDeals = HistoryDealsTotal();
   Print("📊 Total de deals no período: ", totalDeals);

   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;

      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic != MagicNumber) continue;

      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      if(dealSymbol != _Symbol) continue;

      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;

      double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double dealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);

      if(dealType == DEAL_TYPE_BUY)
      {
         volumeBuyTotal += dealVolume;
         precoBuyExec = dealPrice;
         Print("   📌 BUY executada: ", DoubleToString(dealVolume, 2), " @ ", DoubleToString(dealPrice, _Digits));
      }
      else
      {
         volumeSellTotal += dealVolume;
         precoSellExec = dealPrice;
         Print("   📌 SELL executada: ", DoubleToString(dealVolume, 2), " @ ", DoubleToString(dealPrice, _Digits));
      }
   }

   // Se não houve deals, verificar integridade do book e sair
   if(volumeBuyTotal == 0 && volumeSellTotal == 0)
   {
      Print("ℹ️ Nenhum deal para processar");

      // ✅ v3.27: Verificar se ordens extremas existem no book
      // Pode ter falhado ao criar ordens antes da desconexão
      int ordensNoBook = ContarOrdensDoEA();
      Print("🔍 Verificando integridade do book... Ordens encontradas: ", ordensNoBook);

      if(ordensNoBook < 2)
      {
         Print("⚠️ Book incompleto! Recriando ordens extremas...");
         InserirOrdensExtremas();
         Print("✅ Ordens extremas verificadas/recriadas");
      }
      else
      {
         Print("✅ Book íntegro");
      }

      timestampDesconexao = 0;  // ✅ v3.23: Reseta para próxima desconexão
      return;
   }

   // ========== PASSO 2: ENCONTRAR ORDENS NO ARRAY ==========
   if(volumeBuyTotal > 0)
   {
      indiceBuy = EncontrarOrdemPorPrecoETipo(precoBuyExec, ORDER_TYPE_BUY_LIMIT);
      if(indiceBuy >= 0)
         volumeBuyOriginal = originalOrders[indiceBuy].volume;
   }

   if(volumeSellTotal > 0)
   {
      indiceSell = EncontrarOrdemPorPrecoETipo(precoSellExec, ORDER_TYPE_SELL_LIMIT);
      if(indiceSell >= 0)
         volumeSellOriginal = originalOrders[indiceSell].volume;
   }

   // ========== PASSO 3: IDENTIFICAR E PROCESSAR CASO ==========
   double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Print("─────────────────────────────────────");
   Print("📊 Análise:");
   Print("   BUY executada: ", DoubleToString(volumeBuyTotal, 2), " de ", DoubleToString(volumeBuyOriginal, 2));
   Print("   SELL executada: ", DoubleToString(volumeSellTotal, 2), " de ", DoubleToString(volumeSellOriginal, 2));
   Print("   Preço atual: ", DoubleToString(precoAtual, _Digits));

   bool buyTotal = (volumeBuyTotal > 0 && volumeBuyTotal >= volumeBuyOriginal - 0.001);
   bool sellTotal = (volumeSellTotal > 0 && volumeSellTotal >= volumeSellOriginal - 0.001);
   bool buyParcial = (volumeBuyTotal > 0 && volumeBuyTotal < volumeBuyOriginal - 0.001);
   bool sellParcial = (volumeSellTotal > 0 && volumeSellTotal < volumeSellOriginal - 0.001);

   // ---------- CASO A: Uma ordem totalmente executada ----------
   if((buyTotal && volumeSellTotal == 0) || (sellTotal && volumeBuyTotal == 0))
   {
      Print("📋 CASO A: Uma ordem totalmente executada");

      if(buyTotal && indiceBuy >= 0)
      {
         // Remover BUY do array e inserir gain (SELL)
         double precoGain = precoBuyExec + PipsParaPontos(GainPips);
         Print("   Removendo BUY @ ", DoubleToString(precoBuyExec, _Digits));
         Print("   Inserindo SELL gain @ ", DoubleToString(precoGain, _Digits));

         originalOrders[indiceBuy].volume = 0; // Marca para remoção
         AdicionarOrdemAoArray(ORDER_TYPE_SELL_LIMIT, precoGain, volumeBuyOriginal, "Grade Inicial");
      }
      else if(sellTotal && indiceSell >= 0)
      {
         // Remover SELL do array e inserir gain (BUY)
         double precoGain = precoSellExec - PipsParaPontos(GainPips);
         Print("   Removendo SELL @ ", DoubleToString(precoSellExec, _Digits));
         Print("   Inserindo BUY gain @ ", DoubleToString(precoGain, _Digits));

         originalOrders[indiceSell].volume = 0; // Marca para remoção
         AdicionarOrdemAoArray(ORDER_TYPE_BUY_LIMIT, precoGain, volumeSellOriginal, "Grade Inicial");
      }
   }
   // ---------- CASO B: Duas ordens totalmente executadas ----------
   // Ambas executaram = ciclo completo = posição zerada = NÃO MEXE no array
   else if(buyTotal && sellTotal)
   {
      Print("📋 CASO B: Duas ordens totalmente executadas");
      Print("   Ciclo completo - posição zerada");
      Print("   Mantendo ambas ordens no array (não altera nada)");
   }
   // ---------- CASO C: Uma ordem parcialmente executada ----------
   else if((buyParcial && volumeSellTotal == 0) || (sellParcial && volumeBuyTotal == 0))
   {
      Print("📋 CASO C: Uma ordem parcialmente executada");

      if(buyParcial && indiceBuy >= 0)
      {
         double volumeRestante = volumeBuyOriginal - volumeBuyTotal;
         double precoGain = precoBuyExec + PipsParaPontos(GainPips);

         Print("   BUY parcial: ", DoubleToString(volumeBuyTotal, 2), " de ", DoubleToString(volumeBuyOriginal, 2));
         Print("   Atualizando volume para: ", DoubleToString(volumeRestante, 2));
         Print("   Inserindo SELL gain: ", DoubleToString(volumeBuyTotal, 2), " @ ", DoubleToString(precoGain, _Digits));

         originalOrders[indiceBuy].volume = volumeRestante;
         AdicionarOrdemAoArray(ORDER_TYPE_SELL_LIMIT, precoGain, volumeBuyTotal, "Grade Inicial");
      }
      else if(sellParcial && indiceSell >= 0)
      {
         double volumeRestante = volumeSellOriginal - volumeSellTotal;
         double precoGain = precoSellExec - PipsParaPontos(GainPips);

         Print("   SELL parcial: ", DoubleToString(volumeSellTotal, 2), " de ", DoubleToString(volumeSellOriginal, 2));
         Print("   Atualizando volume para: ", DoubleToString(volumeRestante, 2));
         Print("   Inserindo BUY gain: ", DoubleToString(volumeSellTotal, 2), " @ ", DoubleToString(precoGain, _Digits));

         originalOrders[indiceSell].volume = volumeRestante;
         AdicionarOrdemAoArray(ORDER_TYPE_BUY_LIMIT, precoGain, volumeSellTotal, "Grade Inicial");
      }
   }
   // ---------- CASO D: Duas ordens parcialmente executadas ----------
   else if(buyParcial && sellParcial)
   {
      Print("📋 CASO D: Duas ordens parcialmente executadas");

      if(MathAbs(volumeBuyTotal - volumeSellTotal) < 0.001)
      {
         // Quantidades iguais: não mexe no array
         Print("   Quantidades iguais - não altera array");
      }
      else
      {
         // Quantidades diferentes: calcula líquido
         double liquido = MathAbs(volumeBuyTotal - volumeSellTotal);

         if(volumeSellTotal > volumeBuyTotal)
         {
            // Mais SELL executada: mantém BUY, corrige SELL, insere gain BUY
            Print("   Líquido: ", DoubleToString(liquido, 2), " SELL");

            if(indiceSell >= 0)
            {
               double novoVolumeSell = volumeSellOriginal - liquido;
               double precoGain = precoSellExec - PipsParaPontos(GainPips);

               Print("   Mantendo BUY: ", DoubleToString(volumeBuyOriginal, 2));
               Print("   Corrigindo SELL: ", DoubleToString(volumeSellOriginal, 2), " -> ", DoubleToString(novoVolumeSell, 2));
               Print("   Inserindo BUY gain: ", DoubleToString(liquido, 2), " @ ", DoubleToString(precoGain, _Digits));

               originalOrders[indiceSell].volume = novoVolumeSell;
               AdicionarOrdemAoArray(ORDER_TYPE_BUY_LIMIT, precoGain, liquido, "Grade Inicial");
            }
         }
         else
         {
            // Mais BUY executada: mantém SELL, corrige BUY, insere gain SELL
            Print("   Líquido: ", DoubleToString(liquido, 2), " BUY");

            if(indiceBuy >= 0)
            {
               double novoVolumeBuy = volumeBuyOriginal - liquido;
               double precoGain = precoBuyExec + PipsParaPontos(GainPips);

               Print("   Mantendo SELL: ", DoubleToString(volumeSellOriginal, 2));
               Print("   Corrigindo BUY: ", DoubleToString(volumeBuyOriginal, 2), " -> ", DoubleToString(novoVolumeBuy, 2));
               Print("   Inserindo SELL gain: ", DoubleToString(liquido, 2), " @ ", DoubleToString(precoGain, _Digits));

               originalOrders[indiceBuy].volume = novoVolumeBuy;
               AdicionarOrdemAoArray(ORDER_TYPE_SELL_LIMIT, precoGain, liquido, "Grade Inicial");
            }
         }
      }
   }

   // ========== PASSO 4: LIMPAR ORDENS COM VOLUME ZERO ==========
   LimparOrdensVolumeZero();

   // ========== PASSO 5: RESETAR TICKETS E COMENTÁRIOS, SALVAR CSV ==========
   Print("─────────────────────────────────────");
   Print("📝 Resetando tickets e salvando CSV...");

   for(int i = 0; i < ArraySize(originalOrders); i++)
   {
      originalOrders[i].ticket = 0;
      originalOrders[i].comment = "Grade Inicial";
   }

   SalvarEstadoGrade();

   // ========== PASSO 6: CANCELAR TODAS AS ORDENS ==========
   Print("🗑️ Cancelando todas as ordens do book...");
   CancelarTodasOrdensDoEA();
   Sleep(500);

   // ========== PASSO 7: REINICIAR COM GRADE ANTERIOR ==========
   Print("🔄 Reiniciando com grade anterior...");
   InserirOrdensExtremas();

   timestampDesconexao = 0;  // ✅ v3.23: Reseta para próxima desconexão

   Print("========================================");
   Print("✅ SINCRONIZAÇÃO CONCLUÍDA COM SUCESSO");
   Print("📊 Array: ", ArraySize(originalOrders), " ordens");
   Print("📋 Book: ", ContarOrdensDoEA(), " ordens");
   Print("========================================");
}

//+------------------------------------------------------------------+
//| ✅ v3.23: Remove ordens com volume zero do array                 |
//+------------------------------------------------------------------+
void LimparOrdensVolumeZero()
{
   int i = 0;
   while(i < ArraySize(originalOrders))
   {
      if(originalOrders[i].volume <= 0.001)
      {
         // Remove este elemento deslocando os demais
         for(int j = i; j < ArraySize(originalOrders) - 1; j++)
         {
            originalOrders[j] = originalOrders[j + 1];
         }
         ArrayResize(originalOrders, ArraySize(originalOrders) - 1);
         // Não incrementa i, pois o próximo elemento agora está na posição atual
      }
      else
      {
         i++;
      }
   }

   if(ModoDebug)
      Print("🧹 Array limpo. Ordens restantes: ", ArraySize(originalOrders));
}

//+------------------------------------------------------------------+
//| Criar painel de controle                                         |
//+------------------------------------------------------------------+
void CriarPainel()
{
   // Fundo do painel
   ObjectCreate(0, "Panel_Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BGCOLOR, panelColor);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_BACK, false);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Panel_Background", OBJPROP_HIDDEN, true);
   
   // Título
   ObjectCreate(0, "Panel_Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_XDISTANCE, panelX + 60);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_YDISTANCE, panelY + 5);
   ObjectSetString(0, "Panel_Title", OBJPROP_TEXT, "Gradient Grid v3.27");
   ObjectSetString(0, "Panel_Title", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "Panel_Title", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, "Panel_Title", OBJPROP_SELECTABLE, false);
   
   // Botão Iniciar
   ObjectCreate(0, "Panel_BtnIniciar", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_YDISTANCE, panelY + 30);
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnIniciar", OBJPROP_TEXT, "Iniciar Operações");
   ObjectSetString(0, "Panel_BtnIniciar", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_BGCOLOR, clrForestGreen);
   ObjectSetInteger(0, "Panel_BtnIniciar", OBJPROP_BORDER_COLOR, clrBlack);
   
   // Botão Ativar Sem Criar
   ObjectCreate(0, "Panel_BtnAtivarSemCriar", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_YDISTANCE, panelY + 70);
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnAtivarSemCriar", OBJPROP_TEXT, "Ativar Sem Criar Ordens");
   ObjectSetString(0, "Panel_BtnAtivarSemCriar", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetInteger(0, "Panel_BtnAtivarSemCriar", OBJPROP_BORDER_COLOR, clrBlack);

   // Botão Cancelar Ordens
   ObjectCreate(0, "Panel_BtnCancelarOrdens", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_YDISTANCE, panelY + 110);
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnCancelarOrdens", OBJPROP_TEXT, "Cancelar Ordens e Desativar");
   ObjectSetString(0, "Panel_BtnCancelarOrdens", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_BGCOLOR, clrOrange);
   ObjectSetInteger(0, "Panel_BtnCancelarOrdens", OBJPROP_BORDER_COLOR, clrBlack);
   
   // Botão Cancelar Tudo
   ObjectCreate(0, "Panel_BtnCancelarTudo", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_YDISTANCE, panelY + 150);
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_XSIZE, panelWidth - 20);
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "Panel_BtnCancelarTudo", OBJPROP_TEXT, "Fechar Pos/Ord e Desativar");
   ObjectSetString(0, "Panel_BtnCancelarTudo", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_BGCOLOR, clrDarkRed);
   ObjectSetInteger(0, "Panel_BtnCancelarTudo", OBJPROP_BORDER_COLOR, clrBlack);
   
   // Label Status
   ObjectCreate(0, "Panel_Status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_XDISTANCE, panelX + 10);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_YDISTANCE, panelY + 190);
   ObjectSetString(0, "Panel_Status", OBJPROP_TEXT, "Status: Inativo");
   ObjectSetString(0, "Panel_Status", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Panel_Status", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Panel_Status", OBJPROP_HIDDEN, true);

   // Label Lucro/Prejuízo (HEDGE e NETTING)
   if(LucroAlvo > 0 || PrejuizoMaximo < 0)
   {
      // ✅ v3.20: Deletar objeto existente antes de recriar (fix atualização MT5)
      ObjectDelete(0, "Panel_LucroPrejuizo");
      ObjectCreate(0, "Panel_LucroPrejuizo", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "Panel_LucroPrejuizo", OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, "Panel_LucroPrejuizo", OBJPROP_YDISTANCE, panelY + 218);
      ObjectSetString(0, "Panel_LucroPrejuizo", OBJPROP_TEXT, "L/P: R$ 0.00");
      ObjectSetString(0, "Panel_LucroPrejuizo", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "Panel_LucroPrejuizo", OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, "Panel_LucroPrejuizo", OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, "Panel_LucroPrejuizo", OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, "Panel_LucroPrejuizo", OBJPROP_HIDDEN, true);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Atualizar status visual                                          |
//+------------------------------------------------------------------+
void AtualizarStatusVisual()
{
   if(robotAtivo)
   {
      ObjectSetString(0, "Panel_Status", OBJPROP_TEXT, "Status: Ativo");
      ObjectSetInteger(0, "Panel_Status", OBJPROP_COLOR, clrRoyalBlue);
   }
   else
   {
      ObjectSetString(0, "Panel_Status", OBJPROP_TEXT, "Status: Inativo");
      ObjectSetInteger(0, "Panel_Status", OBJPROP_COLOR, clrRed);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Atualizar painel de Lucro/Prejuízo                               |
//+------------------------------------------------------------------+
void AtualizarPainelLucroPrejuizo()
{
   // Funciona tanto em HEDGE quanto NETTING
   if(LucroAlvo <= 0 && PrejuizoMaximo >= 0)
      return;

   double lucroPrejuizoAtual = ObterLucroPrejuizoTotal();
   color cor = lucroPrejuizoAtual >= 0 ? clrGreen : clrRed;

   // ✅ v3.22: Mostrar status do Break Even e Trailing Loss
   string texto;
   if(breakEvenAtivado)
   {
      // prejuizoDinamico é o LUCRO MÍNIMO garantido (valor positivo)
      texto = StringFormat("L/P: R$ %s [Min: R$ %s]",
               DoubleToString(lucroPrejuizoAtual, 2),
               DoubleToString(prejuizoDinamico, 2));
      cor = clrBlue;  // Azul indica proteção ativa
   }
   else
   {
      texto = StringFormat("L/P: R$ %s", DoubleToString(lucroPrejuizoAtual, 2));
   }

   ObjectSetString(0, "Panel_LucroPrejuizo", OBJPROP_TEXT, texto);
   ObjectSetInteger(0, "Panel_LucroPrejuizo", OBJPROP_COLOR, cor);
}

//+------------------------------------------------------------------+
//| Verificar horário de fechamento                                  |
//+------------------------------------------------------------------+
void VerificarHorarioFechamento()
{
   MqlDateTime tempo;
   TimeCurrent(tempo);
   
   string horaParts[];
   int size = StringSplit(HorarioFechamento, ':', horaParts);
   
   if(size != 2)
      return;
   
   int horaFechamento = (int)StringToInteger(horaParts[0]);
   int minutoFechamento = (int)StringToInteger(horaParts[1]);
   
   bool estaNaJanela = false;
   
   if(tempo.hour == horaFechamento && 
      tempo.min >= minutoFechamento && 
      tempo.min < minutoFechamento + 15)
   {
      estaNaJanela = true;
   }
   
   if(estaNaJanela)
   {
      Print("⏰ Executando fechamento programado...");

      // ✅ v3.25: Criar backup do CSV antes de desativar
      BackupCSV();

      if(Persistencia == PERSISTENCIA_FECHAR_ORDENS)
         SalvarEstadoGrade();
      
      bool statusAnterior = robotAtivo;
      robotAtivo = false;
      AtualizarStatusVisual();
      
      if(Persistencia == PERSISTENCIA_FECHAR_TUDO)
      {
         if(ModoDebug)
            Print("Fechando TODAS as posições...");
         
         FecharPosicoes();
         Sleep(1000);
         
         if(ModoDebug)
            Print("Cancelando TODAS as ordens pendentes...");
         
         CancelarOrdensPendentes();
         Sleep(500);
         CancelarOrdensPendentes();
      }
      else if(Persistencia == PERSISTENCIA_FECHAR_ORDENS)
      {
         if(ModoDebug)
            Print("Cancelando APENAS ordens pendentes...");
         
         SalvarEstadoGrade();
         CancelarOrdensPendentes();
         Sleep(500);
         CancelarOrdensPendentes();
         
         robotAtivo = false;
         AtualizarStatusVisual();
         return;
      }
      else if(Persistencia == PERSISTENCIA_DESATIVAR)
      {
         robotAtivo = false;
         AtualizarStatusVisual();
         return;
      }
      
      if(Persistencia != PERSISTENCIA_FECHAR_TUDO)
         robotAtivo = statusAnterior;
      
      AtualizarStatusVisual();
      
      Print("✅ Fechamento executado às ", TimeToString(TimeCurrent()));
   }
}

//+------------------------------------------------------------------+
//| Verificar horário de início                                      |
//+------------------------------------------------------------------+
void VerificarHorarioInicio()
{
   if(robotAtivo)
      return;

   MqlDateTime tempo;
   TimeCurrent(tempo);

   // ✅ v3.15: Resetar flag de meta atingida quando mudar o dia
   // ✅ v3.21: Resetar também o timestamp de lucro/prejuízo
   // ✅ v3.23: Resetar também Break Even e Trailing Loss
   if(diaUltimaVerificacao != tempo.day)
   {
      if(ModoDebug)
         Print("📅 Novo dia detectado. Resetando flags de meta, lucro/prejuízo e Break Even/Trailing.");

      metaAtingidaHoje = false;
      ultimoResetLucroPrejuizo = 0;  // ✅ v3.21: Novo dia = começa do zero

      // ✅ v3.23: Resetar Break Even e Trailing Loss para novo dia
      breakEvenAtivado = false;
      prejuizoDinamico = 0;
      nivelBaseTrailing = 0;

      diaUltimaVerificacao = tempo.day;
   }

   // ✅ v3.15: Se meta foi atingida hoje, NÃO reativar automaticamente
   if(metaAtingidaHoje)
   {
      if(ModoDebug)
         Print("🚫 Meta já atingida hoje. Reativação automática bloqueada.");
      return;
   }

   string horaParts[];
   int size = StringSplit(HorarioInicio, ':', horaParts);

   if(size != 2)
      return;

   int horaInicio = (int)StringToInteger(horaParts[0]);
   int minutoInicio = (int)StringToInteger(horaParts[1]);

   bool estaNaJanela = false;

   if(tempo.hour == horaInicio &&
      tempo.min >= minutoInicio &&
      tempo.min < minutoInicio + 15)
   {
      estaNaJanela = true;
   }

   if(estaNaJanela)
   {
      Print("⏰ Executando início automático...");

      robotAtivo = true;
      AtualizarStatusVisual();

      string nomeArquivo = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

      if(IniciarGradeAnterior && FileIsExist(nomeArquivo, FILE_COMMON))
      {
         CarregarGradeAnterior();
      }
      else
      {
         if(ModoDebug)
            Print("Não encontrada grade anterior. Criando grade inicial.");
         CriarGradeInicialCompleta();
      }

      Print("✅ Início automático executado às ", TimeToString(TimeCurrent()));
   }
}

//+------------------------------------------------------------------+
//| Handlers dos botões                                               |
//+------------------------------------------------------------------+
void OnClickBtnIniciar()
{
   if(robotAtivo)
      return;

   // ✅ v3.15: Reset manual da flag (permite forçar reativação)
   if(metaAtingidaHoje)
   {
      Print("📢 Usuário forçou reativação após meta atingida");
      metaAtingidaHoje = false;
   }

   robotAtivo = true;
   AtualizarStatusVisual();

   string nomeArquivo = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);

   if(IniciarGradeAnterior && FileIsExist(nomeArquivo, FILE_COMMON))
   {
      CarregarGradeAnterior();
   }
   else
   {
      if(ModoDebug)
         Print("Criando grade inicial...");
      CriarGradeInicialCompleta();
   }

   if(ModoDebug)
      Print("✅ Robô ativado manualmente");
}

void OnClickBtnAtivarSemCriar()
{
   if(robotAtivo)
      return;

   // ✅ v3.19: Carregar array do CSV para mapear ordens existentes no book
   string nomeArquivo = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);
   if(FileIsExist(nomeArquivo, FILE_COMMON))
   {
      CarregarGradeAnterior(false);  // false = não criar ordens, só carregar array
      if(ModoDebug)
         Print("📂 Array carregado do CSV (", ArraySize(originalOrders), " ordens mapeadas)");
   }

   robotAtivo = true;
   AtualizarStatusVisual();

   if(ModoDebug)
      Print("✅ Robô ativado sem criar ordens");
}

void OnClickBtnCancelarOrdens()
{
   robotAtivo = false;
   
   if(ArraySize(originalOrders) > 0)
      SalvarEstadoGrade();
   
   CancelarOrdensPendentes();
   AtualizarStatusVisual();
   
   if(ModoDebug)
      Print("✅ Ordens canceladas e robô desativado");
}

void OnClickBtnCancelarTudo()
{
   robotAtivo = false;
   
   CancelarOrdensPendentes();
   FecharPosicoes();
   AtualizarStatusVisual();
   
   if(ModoDebug)
      Print("✅ Ordens e posições canceladas");
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetDeviationInPoints(Slippage);
   trade.SetExpertMagicNumber(MagicNumber);

   isHedge = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   
   if(ModoDebug)
      Print("Tipo de conta: ", isHedge ? "HEDGE" : "NETTING");
   
   if(LucroAlvo > 0 || PrejuizoMaximo < 0)
   {
      Print("============================================");
      Print("✅ Controle de Lucro/Prejuízo ATIVADO");
      Print("Modo: ", isHedge ? "HEDGE (filtra por MagicNumber)" : "NETTING (posição consolidada)");
      if(LucroAlvo > 0)
         Print("Meta de lucro: R$ ", DoubleToString(LucroAlvo, 2));
      if(PrejuizoMaximo < 0)
         Print("Limite de prejuízo: R$ ", DoubleToString(PrejuizoMaximo, 2));
      if(!isHedge)
         Print("⚠️ NETTING: Controla resultado do símbolo inteiro");
      Print("============================================");
   }
   
   if(ModoBrasileiro)
   {
      pontoPorPip = Point();
      digitosPips = _Digits;
   }
   else
   {
      pontoPorPip = _Digits == 3 || _Digits == 5 ? Point() * 10 : Point();
      digitosPips = _Digits == 3 || _Digits == 5 ? _Digits - 1 : _Digits;
   }
   
   // Validar tamanho do lote
   if(TamanhoLote <= 0)
   {
      Print("❌ Erro: Tamanho do lote deve ser maior que zero!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // ✅ VALIDAÇÃO NOVA v3.08: Verificar lote mínimo
   double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   if(TamanhoLote < volumeMin)
   {
      Print("============================================");
      Print("❌ ERRO: TAMANHO DO LOTE INVÁLIDO!");
      Print("Você configurou: ", DoubleToString(TamanhoLote, 2));
      Print("Lote mínimo do ativo ", _Symbol, ": ", DoubleToString(volumeMin, 2));
      Print("SOLUÇÃO: Configure TamanhoLote >= ", DoubleToString(volumeMin, 2));
      Print("============================================");
      
      // Mostrar alerta visual
      Alert("ERRO: TamanhoLote (", DoubleToString(TamanhoLote, 2), 
            ") é menor que o mínimo permitido (", DoubleToString(volumeMin, 2), ")!");
      
      return INIT_PARAMETERS_INCORRECT;
   }

   // ✅ v3.22: Inicializar timestamp de sincronização
   ultimaSincronizacao = TimeCurrent();

   CriarPainel();
   
   robotAtivo = (StatusInicial == STATUS_ATIVO);
   AtualizarStatusVisual();
   
   ArrayResize(originalOrders, 0);
   
   if(robotAtivo)
   {
      string nomeArquivo = StringFormat("%s_%d_Grade.csv", _Symbol, MagicNumber);
      bool csvExiste = FileIsExist(nomeArquivo, FILE_COMMON);
      
      if(IniciarGradeAnterior && csvExiste)
      {
         if(ModoDebug)
            Print("📂 Carregando grade anterior do CSV...");
         
         CarregarGradeAnterior();
      }
      else
      {
         if(!csvExiste && ModoDebug)
            Print("📄 CSV não encontrado. Criando grade inicial...");
         else if(ModoDebug)
            Print("🔄 IniciarGradeAnterior = false. Criando grade nova...");
         
         CriarGradeInicialCompleta();
      }
   }
   
   if(ModoDebug)
   {
      Print("============================================");
      Print("✅ Gradient Grid v3.26 VOLUMES inicializado!");
      Print("✅ v3.26: Arredondamento tick size (corrige J/K)");
      Print("✅ v3.20: Fix label L/P (update MT5)");
      Print("✅ v3.18: Verificação ativa de cancelamento");
      Print("✅ v3.15: Bloqueia reativação automática após meta");
      Print("✅ Trata execuções PARCIAIS e COMPLETAS");
      Print("Ponto por Pip: ", DoubleToString(pontoPorPip, 8));
      Print("Dígitos: ", digitosPips);
      Print("Status: ", robotAtivo ? "Ativo" : "Inativo");
      Print("============================================");
   }

   // ✅ v3.22: Timer para detectar desconexão/reconexão
   EventSetTimer(5);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // ✅ v3.22: Parar timer
   EventKillTimer();

   if(robotAtivo || ArraySize(originalOrders) > 0)
   {
      SalvarEstadoGrade();

      if(ModoDebug)
         Print("💾 Estado da grade salvo ao desligar EA");
   }

   ObjectsDeleteAll(0, "Panel_");

   if(ModoDebug)
      Print("👋 EA finalizado, motivo: ", reason);
}

//+------------------------------------------------------------------+
//| ✅ v3.22: Timer para detectar desconexão/reconexão               |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      if(!emDesconexao)
      {
         emDesconexao = true;
         timestampDesconexao = TimeCurrent();  // ✅ v3.23: Guarda momento exato
         Print("🔴 DESCONEXÃO detectada via Timer às ", TimeToString(timestampDesconexao, TIME_DATE|TIME_SECONDS));
      }
   }
   else
   {
      if(emDesconexao)
      {
         emDesconexao = false;
         Print("========================================");
         Print("✅ RECONEXÃO detectada via Timer!");

         if(robotAtivo)
         {
            Print("Iniciando sincronização automática...");
            Print("========================================");
            SincronizarComServidor();
         }
         else
         {
            Print("EA desativado - sincronização NÃO executada");
            Print("========================================");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(InicioAutomatico && !robotAtivo)
   {
      VerificarHorarioInicio();
   }

   if(!robotAtivo)
   {
      ChartRedraw();
      return;
   }

   if(Persistencia != PERSISTENCIA_MANTER)
   {
      VerificarHorarioFechamento();
   }

   // Verificar meta de lucro/prejuízo (funciona em HEDGE e NETTING)
   if(robotAtivo && (LucroAlvo > 0 || PrejuizoMaximo < 0))
   {
      VerificarMetaLucroPrejuizo();
      AtualizarPainelLucroPrejuizo();
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "Panel_BtnIniciar")
         OnClickBtnIniciar();
      else if(sparam == "Panel_BtnAtivarSemCriar")
         OnClickBtnAtivarSemCriar();
      else if(sparam == "Panel_BtnCancelarOrdens")
         OnClickBtnCancelarOrdens();
      else if(sparam == "Panel_BtnCancelarTudo")
         OnClickBtnCancelarTudo();
   }
}

//+------------------------------------------------------------------+
//| 🎯 OnTradeTransaction - VERSÃO v3.10 VOLUMES                    |
//| ✅ Compara dealVolume vs volumeOriginal                         |
//| ✅ Trata execuções PARCIAIS e COMPLETAS                         |
//| ✅ v3.10: Consolida ordens do mesmo tipo/preço                  |
//| ✅ v3.10 Item 6: Não reseta ticket (rastreabilidade)            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Validações iniciais
   if(!robotAtivo)
      return;
   
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   
   ulong dealTicket = trans.deal;
   
   if(dealTicket <= 0)
      return;
   
   if(!HistoryDealSelect(dealTicket))
      return;
   
   long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   
   if(dealMagic != MagicNumber)
      return;
   
   string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   
   if(dealSymbol != _Symbol)
      return;
   
   // Obter dados do deal
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   ulong ordemTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
   double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);  // ⭐ VOLUME EXECUTADO
   
   // Ignorar deals que não são BUY ou SELL
   if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
      return;
   
   if(ModoDebug)
   {
      Print("========================================");
      Print("📊 DEAL DETECTADO!");
      Print("Deal Ticket: ", dealTicket);
      Print("Ordem Ticket: #", ordemTicket);
      Print("Tipo: ", EnumToString(dealType));
      Print("Volume executado: ", DoubleToString(dealVolume, 2));
      Print("========================================");
   }
   
   // ===== 🔍 BUSCAR ordem no array por TICKET =====
   int indiceOrdemExecutada = EncontrarOrdemPorTicket(ordemTicket);
   
   if(indiceOrdemExecutada < 0)
   {
      if(ModoDebug)
      {
         Print("========================================");
         Print("❌ ERRO: Ordem #", ordemTicket, " NÃO encontrada no array!");
         Print("========================================");
      }
      return;
   }
   
   // ✅ PEGAR DADOS ORIGINAIS DO ARRAY
   double precoOriginal = originalOrders[indiceOrdemExecutada].originalPrice;
   double volumeOriginal = originalOrders[indiceOrdemExecutada].volume;
   
   if(ModoDebug)
   {
      Print("✅ Ordem encontrada no array!");
      Print("Preço original: ", DoubleToString(precoOriginal, _Digits));
      Print("Volume no array: ", DoubleToString(volumeOriginal, 2));
   }
   
   // ===== 🎯 NOVA LÓGICA: COMPARAR VOLUMES =====
   
   // 🔍 VERIFICAR: É execução PARCIAL ou COMPLETA?
   double tolerancia = 0.001; // Tolerância para comparação de doubles
   
   if(dealVolume < volumeOriginal - tolerancia)
   {
      // ⚠️ EXECUÇÃO PARCIAL!
      
      Print("========================================");
      Print("⚠️ EXECUÇÃO PARCIAL DETECTADA!");
      Print("Volume executado: ", DoubleToString(dealVolume, 2));
      Print("Volume original: ", DoubleToString(volumeOriginal, 2));
      Print("Volume restante: ", DoubleToString(volumeOriginal - dealVolume, 2));
      Print("========================================");
      
      // 1️⃣ CRIAR ordem oposta com volume EXECUTADO
      double novoPreco;
      ENUM_ORDER_TYPE novoTipo;
      string novoComentario;
      
      if(dealType == DEAL_TYPE_BUY)
      {
         novoPreco = precoOriginal + PipsParaPontos(GainPips);
         novoTipo = ORDER_TYPE_SELL_LIMIT;
         novoComentario = StringFormat("AutoSell:%I64u", dealTicket);
      }
      else
      {
         novoPreco = precoOriginal - PipsParaPontos(GainPips);
         novoTipo = ORDER_TYPE_BUY_LIMIT;
         novoComentario = StringFormat("AutoBuy:%I64u", dealTicket);
      }
      
      // ✅ v3.10: Adicionar ordem oposta com consolidação
      AdicionarOrdemAoArray(novoTipo, novoPreco, dealVolume, novoComentario);

      // 2️⃣ ATUALIZAR volume no array (NÃO remover ordem!)
      originalOrders[indiceOrdemExecutada].volume = volumeOriginal - dealVolume;
      // ✅ v3.10 Item 6: NÃO resetar ticket (manter rastreamento)
      
      if(ModoDebug)
         Print("✅ Volume atualizado no array: ", DoubleToString(originalOrders[indiceOrdemExecutada].volume, 2));
   }
   else
   {
      // ✅ EXECUÇÃO COMPLETA!
      
      Print("========================================");
      Print("✅ EXECUÇÃO COMPLETA!");
      Print("Volume executado: ", DoubleToString(dealVolume, 2));
      Print("Volume original: ", DoubleToString(volumeOriginal, 2));
      Print("========================================");
      
      // 1️⃣ CRIAR ordem oposta com volume TOTAL
      double novoPreco;
      ENUM_ORDER_TYPE novoTipo;
      string novoComentario;
      
      if(dealType == DEAL_TYPE_BUY)
      {
         novoPreco = precoOriginal + PipsParaPontos(GainPips);
         novoTipo = ORDER_TYPE_SELL_LIMIT;
         novoComentario = StringFormat("AutoSell:%I64u", dealTicket);
      }
      else
      {
         novoPreco = precoOriginal - PipsParaPontos(GainPips);
         novoTipo = ORDER_TYPE_BUY_LIMIT;
         novoComentario = StringFormat("AutoBuy:%I64u", dealTicket);
      }
      
      // ✅ v3.10: Adicionar ordem oposta com consolidação
      AdicionarOrdemAoArray(novoTipo, novoPreco, volumeOriginal, novoComentario);

      // 2️⃣ REMOVER ordem executada do array
      RemoverOrdemPorTicket(ordemTicket);
      
      if(ModoDebug)
         Print("✅ Ordem original removida do array");
   }
   
   // ===== 🔄 ATUALIZAR as 2 extremas no MT5 =====
   InserirOrdensExtremas();
   
   // ===== 💾 SALVAR estado =====
   SalvarEstadoGrade();
   
   if(ModoDebug)
   {
      Print("========================================");
      Print("✅ PROCESSAMENTO COMPLETO!");
      Print("Total de ordens no array: ", ArraySize(originalOrders));
      Print("========================================");
   }
}




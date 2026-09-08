Gradient Grid EA v3.26  |  Documentação do Usuário 
GRADIENT GRID EA 
v3.29 
Documentação Técnica do Usuário 
Plataforma: MetaTrader 5     
|   
  Autor: Trading Expert     
|  
   Maio 2026 
© 2025 Trading Expert  |  Página 1 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
© 2025 Trading Expert  |  Página 2 de 29 
Índice 
1.  Introdução ............................................................... 3 
2.  Instalação e Requisitos .................................................. 4 
3.  Painel de Controle ....................................................... 5 
4.  Configuração de Parâmetros ............................................... 6 
5.  Funcionalidades Avançadas ................................................ 14 
6.  Novidades da v3.22 → v3.29 ............................................... 22 
7.  Exemplos de Configuração ................................................. 27 
8.  Troubleshooting .......................................................... 30 
9.  Referência Técnica ....................................................... 33 
10. Glossário ................................................................ 36 
 
  
Gradient Grid EA v3.26  |  Documentação do Usuário 
1. INTRODUÇÃO 
1.1 Visão Geral 
O Gradient Grid EA v3.29 é um Expert Advisor (robô de trading) para MetaTrader 5 que opera 
utilizando a estratégia de grade simétrica com gradiente progressivo. 
Conceito Principal: 
• Cria uma 'escada' de ordens de compra (BUY_LIMIT) abaixo do BID 
• Cria uma 'escada' de ordens de venda (SELL_LIMIT) acima do BID 
• Quando uma ordem é executada, cria automaticamente uma ordem oposta (gain) 
• Mantém a grade funcionando continuamente 
• Referência: BID (melhor preço de compra no book de ofertas) 
1.2 Características Principais 
Grade Parcial Otimizada 
• Apenas 2 ordens no MT5 por vez (1 BUY + 1 SELL) 
• Grade completa armazenada em memória e arquivo CSV 
• Performance superior e sem rejeições da corretora 
• Atualização automática das ordens extremas 
• Consolidação inteligente de ordens (v3.10): ordens do mesmo tipo/preço são 
automaticamente mescladas 
Multiplicadores Progressivos 
• K (Distância): Aumenta progressivamente a distância entre ordens 
• J (Volume): Aumenta progressivamente o volume das ordens 
• Permite estratégias de escala e gerenciamento de risco 
• v3.26: Arredondamento automático de preços para o tick size do ativo 
Persistência de Grade 
• Salva estado da grade em arquivo CSV 
• Permite reiniciar EA mantendo grade anterior 
• Sobrevive a reinicializações e quedas de conexão 
• v3.25: Backup automático do CSV ao desativar o EA 
Controle de Lucro/Prejuízo (HEDGE e NETTING) 
• Define meta de lucro (R$) 
• Define limite de prejuízo (R$) 
• Ações automáticas ao atingir metas 
• HEDGE: Filtra posições por MagicNumber 
• NETTING: Usa posição consolidada do símbolo (v3.21+) 
Break Even e Trailing Loss Dinâmico (v3.23/v3.24) 
• Break Even por Valor (R$): Quando lucro atinge valor configurado, limite de prejuízo é 
zerado 
• Trailing Loss: A cada R$X de avanço do lucro, o piso de lucro garantido sobe R$X 
• Proteção dinâmica de lucro sem intervenção manual 
© 2025 Trading Expert  |  Página 3 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
Sincronização Inteligente (v3.22/v3.23) 
• Reconstrói o array de ordens usando HistoryDeals após reconexão 
• Detecta e processa execuções ocorridas durante desconexão 
• Janela de sincronização baseada no timestamp exato da desconexão 
Horários Automáticos 
• Início automático em horário configurado 
• Fechamento automático em horário configurado 
• Tipos de persistência configuráveis 
• Ideal para operações intraday 
Painel de Controle Visual 
• 4 botões para controle manual 
• Status visual (Ativo/Inativo) 
• Indicador de lucro/prejuízo em tempo real 
• Interface intuitiva 
Estoque Máximo (v3.28) 
Limite de posições simultâneas configurável (EstoqueMaximo) 
Insere automaticamente ordem Stop no ponto médio entre última executada e próxima pendente 
Volume da Stop = volume da próxima ordem da grade (respeita J) 
HEDGE: fecha posição mais antiga | NETTING: reduz posição consolidada 
Cooldown Pós Stop Loss (v3.29) 
Pausa progressiva ao atingir PrejuizoMaximo, com backoff exponencial (30 → 60 → 120 min) 
Após N tentativas consecutivas, EA desativa para o restante do dia 
Opção para reusar a grade anterior ao retomar (ReusarGradeAposPausa) 
Reativação manual via botão zera o contador de tentativas 
© 2025 Trading Expert  |  Página 4 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
1.3 Changelog Resumido 
Esta seção resume as evoluções entre v3.21 e v3.29. Para histórico completo, veja a Seção 6. 
Versão 
Principal Melhoria 
v3.22 
Sincronização inteligente pós-reconexão com HistoryDeals; Break 
Even dinâmico e Trailing Loss 
v3.23 
Break Even e Trailing Loss usam timestamp exato da desconexão; 
busca de ordem por preço/tipo 
v3.24 
Break Even por Valor (R$) fixo, independente do lucro alvo 
v3.25 
Backup automático do CSV ao desativar o EA; indicação clara de 
sincronização rodada 
v3.26 
Arredondamento de preços para tick size do ativo (corrige J/K em 
ativos como WIN/WDO) 
v3.27 
Verificação do book pós-reconexão: recria ordens extremas se 
ausentes 
v3.28 
v3.29 
Estoque Máximo: ordem Stop de proteção ao atingir limite de posições 
Cooldown com backoff exponencial após stop loss; ação configurável 
após PrejuízoMáximo 
© 2025 Trading Expert  |  Página 5 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
2. INSTALAÇÃO E REQUISITOS 
2.1 Requisitos de Sistema 
Plataforma: 
• MetaTrader 5 (build 3200 ou superior) 
• Sistema operacional: Windows 7+, Linux (Wine), macOS (Wine) 
Tipo de Conta: 
• Qualquer tipo (Netting ou Hedging) 
• Funcionalidades de Lucro/Prejuízo: HEDGE e NETTING (v3.21+) 
• HEDGE: Filtra posições por MagicNumber (ideal para múltiplos EAs) 
• NETTING: Usa posição consolidada do símbolo 
Corretora: 
• Qualquer corretora compatível com MT5 
• Recomendado: Corretoras com spread baixo 
• Testado com: XP, Clear, Modal e similares 
Recursos de Hardware: 
• Mínimo: 2 GB RAM, processador dual-core 
• Recomendado: 4 GB+ RAM, processador quad-core 
• Conexão: Internet estável (mínimo 1 Mbps) 
2.2 Como Instalar 
1. Localize o arquivo Gradiente_Linear_3_29.ex5 
2. Copie para a pasta de EAs do MT5: 
C:\Users\[SEU_USUÁRIO]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\ 
Atalho: No MT5 vá em Arquivo → Abrir Pasta de Dados → MQL5 → Experts 
3. Se você tem o código-fonte (.mq5): abra o MetaEditor (F4), abra o arquivo e compile (F7) 
4. No MT5, pressione Ctrl+N para abrir o Navegador, clique com botão direito em 'Expert 
Advisors' e selecione Atualizar 
5. Arraste o EA para o gráfico do ativo desejado (ex: WIN, WDO, EURUSD) 
6. Configure os parâmetros (ver Seção 4) 
7. Marque 'Permitir trading automático' e clique OK 
2.3 Verificação 
• Painel aparece no canto superior esquerdo do gráfico 
• Ícone de robô visível no canto superior direito 
• Status 'Ativo' ou 'Inativo' exibido no painel 
© 2025 Trading Expert  |  Página 6 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
3. PAINEL DE CONTROLE 
3.1 Layout do Painel 
┌─────────────────────────────┐ 
│  Gradient Grid v3.26        │ 
├─────────────────────────────┤ 
│  [  Iniciar Operações   ]   │ 
│  [ Ativar Sem Criar Ord ]   │ 
│  [ Cancelar Ord e Desativ ] │ 
│  [ Fechar Pos/Ord Desativ ] │ 
├─────────────────────────────┤ 
│  Status: Ativo              │ 
│  L/P: R$ 0,00               │ 
└─────────────────────────────┘ 
3.2 Botão 'Iniciar Operações' 
Ativa o EA e cria/carrega a grade. 
• Ativa o EA (robotAtivo = true) 
• Verifica parâmetro IniciarGradeAnterior: 
◦ Se TRUE e CSV existe → Carrega grade anterior 
◦ Caso contrário → Cria grade nova 
• Cria 2 ordens no MT5 (maior BUY + menor SELL) 
• Status muda para 'Ativo' 
3.3 Botão 'Ativar Sem Criar Ordens' 
Ativa o EA mas NÃO cria nova grade — carrega o CSV e mapeia ordens existentes no book. 
• Útil para retomar operação após reinicialização sem mexer na grade atual 
• EA lê o CSV e sincroniza com ordens que já estão no MT5 (v3.19) 
3.4 Botão 'Cancelar Ordens e Desativar' 
• Desativa o EA 
• Salva estado da grade em CSV 
• v3.25: Cria backup do CSV com timestamp 
• Cancela TODAS as ordens pendentes do EA 
• Posições abertas permanecem 
3.5 Botão 'Fechar Pos/Ord e Desativar' 
• Desativa o EA 
• Cancela TODAS as ordens pendentes 
• Fecha TODAS as posições abertas 
• Zera completamente a operação 
© 2025 Trading Expert  |  Página 7 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
4. CONFIGURAÇÃO DE PARÂMETROS 
4.1 Grupo: Configurações Gerais de Grade 
KMultiplicadorAcima / KMultiplicadorAbaixo 
Tipo: double | Padrão: 0.0 
Multiplicador para distância progressiva entre ordens. Fórmula: 
Dist_Nova = Dist_Anterior × (1 + K) 
Valor de K 
Efeito 
0.0 
Distância fixa entre todas as ordens (grade linear) 
0.2–0.5 
Distância cresce moderadamente (equilíbrio recomendado) 
1.0 
Distância dobra a cada ordem (grade exponencial) 
> 1.0 
Ordens muito espaçadas; usar com critério baseado em 
volatilidade 
IMPORTANTE (v3.26): Os preços calculados pelo multiplicador K são automaticamente 
arredondados para o tick size do ativo, garantindo que as ordens sejam aceitas pela corretora 
mesmo com ativos de tick grande (ex: WIN, WDO). 
4.2 Grupo: Configurações Gerais de Volume 
JMultiplicadorVolumeAcima / JMultiplicadorVolumeAbaixo 
Tipo: double | Padrão: 0.0 
Multiplicador para volume progressivo das ordens. Fórmula: 
Vol_Novo = Vol_Anterior × (1 + J) 
Valor de J 
Efeito 
0.0 
Volume fixo em todas as ordens (mais seguro) 
0.2–0.5 
Volume aumenta gradualmente 
1.0 
Volume dobra a cada ordem (Martingale — risco alto!) 
ATENÇÃO: Volume cresce exponencialmente. Use SEMPRE VolumeMaximo quando J > 0. 
VolumeMaximo 
Tipo: double | Padrão: 0 (sem limite) 
• 0: Sem limite (usa apenas limite da corretora) 
• > 0: Limita o volume máximo por ordem 
© 2025 Trading Expert  |  Página 8 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
4.3 Grade Acima do Preço (SELL_LIMIT) 
Parâmetro 
Tipo 
Padrão 
Descrição 
GapInicialAcima 
double 
50 pips 
DistanciaOrdensAcima 
double 
20 pips 
Distância da 1ª SELL acima do 
BID 
QtdOrdensAcima 
Distância entre ordens SELL 
int 
5 
AtivarGradeAcima 
bool 
true 
Quantidade de ordens SELL 
Habilita/desabilita o lado SELL 
da grade 
4.4 Grade Abaixo do Preço (BUY_LIMIT) 
Parâmetro 
Tipo 
Padrão 
Descrição 
GapInicialAbaixo 
double 
50 pips 
DistanciaOrdensAbaixo 
double 
20 pips 
Distância da 1ª BUY abaixo do 
BID 
QtdOrdensAbaixo 
Distância entre ordens BUY 
int 
5 
AtivarGradeAbaixo 
bool 
true 
Quantidade de ordens BUY 
Habilita/desabilita o lado BUY 
da grade 
4.5 Preço de Referência 
Tipo: double | Padrão: 0 
• 0: Usa o BID atual do mercado como centro da grade 
• > 0: Usa preço fixo específico como centro — ideal para testes ou entradas em nível técnico 
4.6 Volume e Gain 
Parâmetro 
Tipo 
Padrão 
Descrição 
TamanhoLote 
double 
1 
GainPips 
double 
100 pips 
Volume inicial das ordens 
Distância da ordem oposta 
(take profit) 
© 2025 Trading Expert  |  Página 9 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
© 2025 Trading Expert  |  Página 10 de 29 
 
4.7 Persistência 
Parâmetro Tipo Padrão Descrição 
Persistencia enum DESATIVAR Ação ao atingir 
HorarioFechamento 
HorarioInicio string 09:00 Horário de ativação automática 
(HH:MM) 
InicioAutomatico bool true Ativa EA automaticamente no 
HorarioInicio 
HorarioFechamento string 17:30 Horário para executar ação de 
persistência 
IniciarGradeAnterior bool false Carrega grade do CSV ao 
iniciar 
 
Opções de Persistência: 
• PERSISTENCIA_MANTER: Não faz nada — EA continua ativo 
• PERSISTENCIA_FECHAR_ORDENS: Cancela ordens e desativa, mantém posições 
• PERSISTENCIA_FECHAR_TUDO: Fecha posições e ordens, desativa EA 
• PERSISTENCIA_DESATIVAR: Apenas desativa EA, mantém ordens e posições 
 
4.8 Configurações Técnicas 
Parâmetro Tipo Padrão Descrição 
Slippage int 3 pontos Desvio máximo de preço aceito 
MagicNumber int 12345 Identificador único do EA 
ModoBrasileiro bool true Ajusta cálculos para mercado 
B3 
ModoDebug bool false Ativa logs detalhados no 
Journal 
StatusInicial enum INATIVO Estado ao inicializar (ATIVO / 
INATIVO) 
 
  
Gradient Grid EA v3.26  |  Documentação do Usuário 
4.9 Meta de Lucro/Prejuízo (HEDGE e NETTING) 
Parâmetro 
Tipo 
Padrão 
LucroAlvo 
double 
Descrição 
0 (desabilitado) 
Meta de lucro em 
R$ para ação 
automática 
PrejuizoMaximo 
double 
0 (desabilitado) 
Limite de prejuízo 
em R$ (valor 
NEGATIVO!) 
AcaoAoAtingirMeta 
enum 
FECHAR_E_DESATIVAR 
Opções de AcaoAoAtingirMeta: 
O que fazer ao 
atingir lucro ou 
prejuízo 
• ACAO_FECHAR_E_DESATIVAR: Fecha posições, cancela ordens e desativa EA 
• ACAO_FECHAR_E_RECRIAR: Fecha posições, cancela ordens e cria nova grade 
4.10 Break Even e Trailing Loss 
Parâmetro 
Tipo 
Padrão 
Descrição 
UtilizarBreakEven 
bool 
false 
BreakEvenValor 
double 
0 
Habilita o Break Even 
dinâmico 
Lucro (R$) para ativar o 
Break Even 
UtilizarTrailingLoss 
bool 
false 
Habilita o Trailing Loss 
dinâmico 
TrailingLossValor 
double 
10.0 
Incremento do piso de lucro 
(R$) 
4.11 Estoque Máximo (v3.28) 
Limita o número máximo de posições simultâneas. Ao ser atingido, o EA insere uma ordem Stop de 
proteção que reduzirá o estoque caso o mercado continue na direção contrária. 
Parâmetro 
EstoqueMaximo 
Como funciona: 
Tipo 
int 
Padrão 
0 (desabilitado) 
Descrição 
Quantidade máxima 
de posições 
simultâneas. 0 
desabilita o Stop de 
proteção. 
EA monitora o número de posições abertas (filtrado por MagicNumber em HEDGE). 
Ao atingir EstoqueMaximo, calcula o ponto médio entre o preço da última ordem executada e o 
preço da próxima ordem pendente da grade. 
Insere uma ordem Stop (BUY_STOP ou SELL_STOP, conforme o lado acumulado) com volume 
igual ao da próxima ordem da grade. 
© 2025 Trading Expert  |  Página 11 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
Se o mercado continuar contra, a Stop é executada e reduz o estoque (HEDGE: fecha a posição 
mais antiga; NETTING: reduz a consolidada). 
Se o estoque voltar abaixo do limite, a Stop é cancelada automaticamente. 
Recomendação: configure EstoqueMaximo igual à metade da grade total para evitar exposição 
máxima. 
4.12 Ação Após Stop Loss / Cooldown (v3.29) 
Define o que acontece quando o lucro atinge o limite de PrejuizoMaximo (stop loss). Independente 
da AcaoAoAtingirMeta, este parâmetro permite escolher entre desativar, recriar a grade ou entrar 
em cooldown com backoff exponencial. 
Parâmetro 
AcaoAposStopLoss 
PausaInicialMinutos 
Tipo 
enum 
int 
MaxTentativasConsecutivas int 
ReusarGradeAposPausa 
bool 
Opções de AcaoAposStopLoss: 
Padrão 
Descrição 
ACAO_STOP_DESATIVAR Ação ao atingir 
PrejuizoMaximo: 
DESATIVAR, 
RECRIAR ou 
COOLDOWN. 
30 
3 
false 
Duração da 
primeira pausa (em 
minutos) no modo 
cooldown. 
Após quantos stops 
consecutivos o EA 
é desativado para o 
dia. 
Ao retomar do 
cooldown, carrega 
a grade anterior do 
CSV em vez de 
criar nova. 
ACAO_STOP_DESATIVAR: Fecha tudo, cancela ordens e desativa o EA (mesmo comportamento 
das versões anteriores). 
ACAO_STOP_RECRIAR: Fecha tudo, cancela ordens e cria uma nova grade imediatamente. 
ACAO_STOP_COOLDOWN: Fecha tudo e entra em pausa com backoff exponencial; retoma 
sozinho ao final. 
Backoff Exponencial: 
A pausa dobra a cada novo stop consecutivo: PausaInicialMinutos × 2^(tentativa−1). 
Exemplo com PausaInicialMinutos=30 e MaxTentativasConsecutivas=3: 
Tentativa 1 → pausa de 30 minutos 
Tentativa 2 → pausa de 60 minutos 
Tentativa 3 → pausa de 120 minutos 
Após o 3º stop → EA é desativado para o dia (metaAtingidaHoje = true) 
Importante: lucro atingido (LucroAlvo) zera o contador de tentativas; reativação manual via botão 
também reseta o cooldown. 
© 2025 Trading Expert  |  Página 12 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
5. FUNCIONALIDADES AVANÇADAS 
5.1 Grade Parcial (2 Ordens no MT5) 
A Grade Parcial é a principal inovação da arquitetura v3.x. Em vez de criar todas as ordens no 
MT5, o EA mantém apenas as 2 extremas ativas: 
MT5 (2 ordens reais): 
BUY  100450  |  SELL 100550 
MEMÓRIA / CSV (grade completa): 
BUY  100450, 100430, 100410, 100390, 100370 
SELL 100550, 100570, 100590, 100610, 100630 
Quando uma ordem é executada: 
8. OnTradeTransaction detecta o deal 
9. Array é atualizado (remove executada, adiciona gain) 
10. CSV é salvo imediatamente 
11. InserirOrdensExtremas() atualiza as 2 ordens no MT5 
Vantagens: menor latência, sem rejeições, sincronização simplificada, código mais limpo. 
5.2 Multiplicadores Progressivos K e J 
K (distância) e J (volume) criam grades assimétricas e progressivas. 
Exemplo K=0.5 com DistanciaInicial=20 pips: 
SELL 100550 (gap=50, dist=0) 
SELL 100570 (dist=20) 
SELL 100600 (dist=30 → 20×1.5) 
SELL 100645 (dist=45 → 30×1.5) 
Tabela de exposição total com J progressivo (5 ordens, Lote=1.0): 
J 
Vol. Total 
Vol. Máx Individual 
0.0 
Exposição vs J=0 
5.0 
1.0 
1× (base) 
0.2 
7.4 
2.1 
0.5 
1.5× 
13.3 
5.1 
2.7× 
1.0 
31.0 
16.0 
6.2× 
ALERTA: J = 1.0 com 10 ordens = 1.023 contratos sem limite. SEMPRE use VolumeMaximo! 
5.3 Persistência de Grade (CSV) 
O EA salva o estado completo da grade em: 
C:\Users\[USUÁRIO]\AppData\Roaming\MetaQuotes\Common\Files\SYMBOL_MAGICNUMBER_Grade
.csv 
Estrutura do arquivo (v3.26): 
Ticket,Tipo,Preco,Volume,Comentario 
54123456,0,100450.000000,1.000000,Grade Inicial 
0,2,100550.000000,1.000000,Grade Inicial 
© 2025 Trading Expert  |  Página 13 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
v3.25 — Backup Automático: Ao desativar o EA via botão ou horário de fechamento, é criado 
automaticamente um backup com timestamp: 
WINM25_12345_Grade_BKP_20250319_173005.csv 
5.4 Break Even Dinâmico (v3.24) 
Quando o lucro da posição atinge o valor configurado em BreakEvenValor (R$), o limite de prejuízo 
é automaticamente zerado. 
Exemplo: 
PrejuizoMaximo  = -50.0   (limite de perda) 
BreakEvenValor  = 30.0    (gatilho) 
Lucro chega a R$ 30 → PrejuizoDinamico = 0 
Agora o EA só encerra se lucro cair abaixo de R$ 0 
5.5 Trailing Loss Dinâmico (v3.23) 
Após o Break Even ser ativado, a cada incremento de TrailingLossValor (R$) no lucro, o piso de 
lucro garantido sobe na mesma proporção. 
Exemplo com TrailingLossValor = 10: 
Break Even ativado em R$ 30 → piso = R$ 0 
Lucro sobe para R$ 40        → piso = R$ 10 
Lucro sobe para R$ 50        → piso = R$ 20 
Lucro cai para R$ 15         → EA ENCERRA (lucro < piso R$ 20) 
5.6 Sincronização Inteligente Pós-Reconexão (v3.22/v3.23) 
Ao detectar reconexão ao servidor, o EA executa SincronizarComServidor() que: 
12. Registra o timestamp exato da desconexão 
13. Consulta HistoryDeals na janela: timestamp_desconexao → agora 
14. Identifica execuções ocorridas durante o período offline 
15. Processa os 4 casos possíveis: 
◦ Caso A: Uma ordem completamente executada — remove do array, insere gain 
◦ Caso B: Ambas executadas — ciclo completo, mantém array 
◦ Caso C: Uma parcialmente executada — atualiza volume, insere gain parcial 
◦ Caso D: Ambas parcialmente executadas — calcula líquido e ajusta 
16. Salva CSV atualizado e reinicia as 2 ordens extremas 
v3.25: O painel indica claramente se a sincronização foi executada ou não. 
© 2025 Trading Expert  |  Página 14 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
5.7 Controle de Lucro/Prejuízo (HEDGE e NETTING) 
O EA calcula o lucro total considerando: 
• Lucro flutuante de todas as posições abertas (filtradas por MagicNumber em HEDGE) 
• Lucro de todas as operações fechadas no dia (a partir do início do dia ou do último reset) 
• Swap e comissões incluídos 
Comparação HEDGE vs NETTING: 
Aspecto 
HEDGE 
NETTING 
Filtro de posições 
Por MagicNumber (só deste 
EA) 
Múltiplos EAs 
Cada EA controla as suas 
Posição consolidada do 
símbolo 
Todos veem o mesmo 
resultado 
Ideal para 
Múltiplos EAs no mesmo ativo 
EA único por ativo 
© 2025 Trading Expert  |  Página 15 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
5.8 Verificação do Book Pós-Reconexão (v3.27) 
Após uma reconexão ao servidor MT5, mesmo que a sincronização inteligente (v3.22+) não detecte 
deals durante o período offline, o EA verifica se as 2 ordens extremas continuam ativas no book. 
Comportamento: 
Conta as ordens pendentes deste EA no book via ContarOrdensDoEA(). 
Se houver menos de 2 ordens, recria as ordens extremas com base no array em memória. 
Evita situação em que ordens foram canceladas pela corretora ou pelo servidor durante a 
desconexão e a grade fica sem cobertura. 
5.9 Estoque Máximo — Stop de Proteção (v3.28) 
O parâmetro EstoqueMaximo define o número máximo de posições simultâneas. Quando o limite é 
alcançado, o EA insere automaticamente uma ordem Stop de proteção entre a última ordem 
executada e a próxima pendente da grade. 
Cálculo do preço da Stop: 
preco_stop = (preco_ultima_executada + preco_proxima_pendente) / 2  (arredondado para tick 
size) 
Volume e tipo: 
Volume = volume da próxima ordem da grade (respeita o multiplicador J) 
Acumulando BUYs (mercado caindo) → SELL STOP 
Acumulando SELLs (mercado subindo) → BUY STOP 
Quando a Stop é executada: 
HEDGE: fecha a posição mais antiga, zerando seu lucro/prejuízo. 
NETTING: reduz a posição consolidada do símbolo. 
Cancelamento automático: 
Quando o estoque cai abaixo do limite, a ordem Stop é cancelada automaticamente. 
5.10 Cooldown com Backoff Exponencial (v3.29) 
Quando AcaoAposStopLoss = ACAO_STOP_COOLDOWN e o EA atinge o limite de 
PrejuizoMaximo, em vez de desativar imediatamente o EA pausa por um tempo configurável e 
tenta novamente. 
Cada novo stop dobra a duração da pausa (backoff exponencial). Após esgotar 
MaxTentativasConsecutivas, o EA é desativado para o restante do dia (metaAtingidaHoje = true). 
Fluxo: 
PrejuizoMaximo atingido → tentativaAtual++ → entra em cooldown. 
Cancela todas as ordens pendentes e fecha todas as posições. 
Aguarda PausaInicialMinutos × 2^(tentativaAtual−1) minutos. 
Ao final, recria a grade (ou carrega a anterior se ReusarGradeAposPausa = true) e retoma 
operações. 
Resets: 
LucroAlvo atingido zera tentativaAtual (após uma vitória, recomeça a contagem). 
Reativação manual via botão 'Iniciar Operações' também zera tentativaAtual e o cooldown. 
Mudança de dia zera tentativaAtual e o cooldown. 
Painel: 
© 2025 Trading Expert  |  Página 16 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
Durante o cooldown, o painel exibe 'EM COOLDOWN' e o tempo restante em minutos, junto da 
contagem de tentativas (ex: 2/3). 
Durante o cooldown, a sincronização pós-reconexão e o processamento de novos deals são 
bloqueados, evitando que o EA reabra posições enquanto está pausado. 
6. NOVIDADES DA v3.22 À v3.29 
v3.29 — Cooldown com Backoff Exponencial Após Stop Loss 
Principal novidade desta versão. Permite ao EA reagir de forma escalonada ao atingir o limite de 
prejuízo, em vez de simplesmente desativar. 
Novo enum ENUM_ACAO_STOP com três opções: 
ACAO_STOP_DESATIVAR: comportamento padrão das versões anteriores — fecha tudo e 
desativa. 
ACAO_STOP_RECRIAR: fecha tudo e cria nova grade imediatamente. 
ACAO_STOP_COOLDOWN: pausa com backoff exponencial e retoma operações ao final. 
Novos parâmetros: AcaoAposStopLoss, PausaInicialMinutos, MaxTentativasConsecutivas, 
ReusarGradeAposPausa. 
Backoff: a pausa dobra a cada nova tentativa (30 → 60 → 120 min). Após esgotar tentativas, EA 
desativa para o dia. 
Resets automáticos: lucro atingido, reativação manual e mudança de dia zeram o contador. 
v3.28 — Estoque Máximo (Stop de Proteção) 
Novo parâmetro EstoqueMaximo limita o número de posições simultâneas. Ao atingir o limite, o EA 
insere automaticamente uma ordem Stop entre a última executada e a próxima pendente. 
Volume da Stop = volume da próxima ordem da grade (respeita J). 
HEDGE: fecha a posição mais antiga ao executar | NETTING: reduz a consolidada. 
A Stop é cancelada automaticamente quando o estoque volta abaixo do limite. 
Ideal para grades com J > 0, onde o volume cresce — limita exposição máxima sem perder 
geometria da grade. 
v3.27 — Verificação do Book Pós-Reconexão 
Adiciona verificação de integridade do book após reconexão ao servidor. Se a sincronização não 
encontrou deals no período offline mas o book contém menos de 2 ordens extremas, o EA recria as 
ordens com base no array em memória. 
Resolve o caso em que a corretora ou o servidor cancela ordens durante a desconexão sem 
registrar deals correspondentes. 
Garante que a grade sempre permaneça com cobertura ativa após qualquer reconexão. 
v3.26 — Arredondamento por Tick Size 
Principal novidade desta versão. Todos os preços calculados pelo EA (grade inicial, ordens de 
gain, sincronização) são agora automaticamente arredondados para o tick size do ativo antes de 
serem enviados ao MT5. 
Nova função ArredondarPreco(): 
double ArredondarPreco(double preco) { 
double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); 
if(tickSize > 0) 
preco = MathRound(preco / tickSize) * tickSize; 
return NormalizeDouble(preco, _Digits); 
} 
© 2025 Trading Expert  |  Página 17 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
Esta correção é especialmente importante para: 
• Ativos da B3 como WIN e WDO onde o tick size é 5 pontos 
• Configurações com multiplicador J alto, que geram preços não-múltiplos do tick 
• Configurações com multiplicador K em distâncias não-múltiplas do tick 
Impacto: Elimina erros de 'preço inválido' ao criar ordens em ativos com tick size > 1 ponto. 
v3.25 — Backup Automático do CSV 
• Ao desativar o EA (via botão 'Cancelar Ordens e Desativar', horário de fechamento ou 
OnDeinit), um backup do CSV é criado automaticamente com data e hora no nome 
• Formato: SYMBOL_MAGIC_Grade_BKP_AAAAMMDD_HHMMSS.csv 
• Útil para auditoria, recuperação de grades antigas ou comparação de estados 
• O backup não substitui o arquivo principal — ambos coexistem 
v3.25 — Sincronização com Indicação Clara 
• O painel exibe mensagem diferenciada conforme sincronização foi executada ou não 
• Facilita diagnóstico após reconexão 
v3.24 — Break Even por Valor (R$) 
• Novo parâmetro BreakEvenValor: define um valor fixo em R$ para ativar o Break Even, 
independente de qualquer percentual do lucro alvo 
• Complementa UtilizarBreakEven (bool) e é mais intuitivo para traders de ativos brasileiros 
• Quando lucro >= BreakEvenValor: prejuizoDinamico = 0 (piso zerado) 
• O nível base para o Trailing Loss é definido neste momento 
v3.23 — Trailing Loss e Fix de Sincronização 
• Trailing Loss: A cada TrailingLossValor (R$) de avanço do lucro após Break Even, o piso de 
lucro garantido sobe no mesmo valor — nunca desce 
• Fix de Sincronização: A janela de busca de HistoryDeals usa agora o timestamp exato da 
desconexão (não a última sincronização), evitando deals duplicados 
• Nova função EncontrarOrdemPorPrecoETipo() para uso durante a sincronização 
v3.22 — Sincronização Inteligente 
• OnTimer passa a detectar reconexão (retorno de emDesconexao = true para false) 
• SincronizarComServidor() reconstrói o array com base no HistoryDeals do período offline 
• Variáveis de controle: ultimaSincronizacao, emDesconexao, timestampDesconexao 
• Reinicia Break Even e Trailing Loss ao recriar grade (ACAO_FECHAR_E_RECRIAR) 
© 2025 Trading Expert  |  Página 18 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
Versão 
Funcionalidade 
Impacto 
v3.26 
Arredondamento por tick size 
Crítico — corrige criação de ordens 
em ativos B3 
v3.25 
Backup automático CSV 
Segurança — preserva histórico de 
grades 
v3.25 
Indicação de sincronização 
UX — diagnóstico mais rápido 
v3.24 
Break Even por valor R$ 
v3.23 
Proteção — gatilho mais preciso 
Trailing Loss dinâmico 
Proteção — piso de lucro 
progressivo 
v3.23 
Fix timestamp desconexão 
Robustez — sincronização sem 
duplicatas 
v3.22 
Sincronização pós-reconexão 
Robustez — recuperação 
automática 
v3.27 
Verificação do book pós-reconexão 
Robustez — repõe ordens extremas 
após desconexão 
v3.28 
Estoque Máximo (Stop de proteção) 
Proteção — limita exposição máxima 
da grade 
v3.29 
Cooldown após stop loss 
Proteção — pausa progressiva contra 
perdas em série 
© 2025 Trading Expert  |  Página 19 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
7. EXEMPLOS DE CONFIGURAÇÃO 
7.1 Grade Padrão Intraday (WIN) 
Configuração conservadora para mini-índice, operação intraday: 
GapInicialAcima      = 50 
DistanciaOrdensAcima = 20 
QtdOrdensAcima       = 5 
AtivarGradeAcima     = true 
GapInicialAbaixo      = 50 
DistanciaOrdensAbaixo = 20 
QtdOrdensAbaixo       = 5 
AtivarGradeAbaixo     = true 
TamanhoLote          = 1 
GainPips             = 100 
MagicNumber          = 12345 
ModoBrasileiro       = true 
HorarioInicio        = 09:00 
HorarioFechamento    = 17:30 
Persistencia         = FECHAR_TUDO 
InicioAutomatico     = true 
7.2 Grade com Gradiente (K=0.3) 
Grade com distâncias crescentes — captura movimentos maiores sem expor muito nos extremos: 
KMultiplicadorAcima  = 0.3 
KMultiplicadorAbaixo = 0.3 
DistanciaOrdensAcima  = 20 
DistanciaOrdensAbaixo = 20 
GainPips             
= 60 
7.3 Grade com Volume Progressivo (J=0.3) 
Volume aumenta 30% a cada ordem. SEMPRE com VolumeMaximo: 
JMultiplicadorVolumeAcima  = 0.3 
JMultiplicadorVolumeAbaixo = 0.3 
TamanhoLote               = 1 
VolumeMaximo              = 3 
7.4 Com Meta e Break Even 
Encerra com lucro e protege com Break Even + Trailing Loss: 
LucroAlvo             = 200.0 
PrejuizoMaximo        = -50.0 
AcaoAoAtingirMeta     = FECHAR_E_DESATIVAR 
UtilizarBreakEven     = true 
BreakEvenValor        = 60.0      // Ativa ao ganhar R$ 60 
UtilizarTrailingLoss  = true 
TrailingLossValor     = 15.0      // Piso sobe R$ 15 a cada R$ 15 de ganho 
7.5 Grade Apenas BUY (Tendência de Baixa) 
Operar apenas o lado da compra — grade assimétrica: 
AtivarGradeAcima  = false 
AtivarGradeAbaixo = true 
GapInicialAbaixo      = 50 
© 2025 Trading Expert  |  Página 20 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
DistanciaOrdensAbaixo = 30 
QtdOrdensAbaixo       = 8 
7.6 Reinício com Grade Anterior 
Para retomar exatamente de onde parou após reinicialização: 
IniciarGradeAnterior = true 
StatusInicial        = INATIVO 
InicioAutomatico     = true 
© 2025 Trading Expert  |  Página 21 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
7.7 Com Estoque Máximo e Cooldown 
Configuração que limita exposição e usa cooldown progressivo após stops: 
EstoqueMaximo            
= 5 
LucroAlvo                
PrejuizoMaximo           
AcaoAposStopLoss         
PausaInicialMinutos      
= 200.0 
= -100.0 
= ACAO_STOP_COOLDOWN 
= 30 
MaxTentativasConsecutivas = 3 
ReusarGradeAposPausa     = false 
Comportamento esperado: ao atingir 5 posições, Stop de proteção é inserida. Ao atingir prejuízo de 
R$ 100, EA pausa 30 min e tenta de novo. No 2º stop, pausa 60 min. No 3º, pausa 120 min. No 4º, 
EA desativa para o dia. 
8. TROUBLESHOOTING 
8.1 EA Não Cria Ordens 
Sintoma 
Causa Provável 
Solução 
Painel mostra 'Inativo' 
EA não foi ativado 
Clique 'Iniciar Operações' 
Erro no Journal 
Trading automático 
desabilitado 
Habilitar 'Permitir trading automático' 
no MT5 
Lote inválido 
TamanhoLote abaixo 
do mínimo 
Verificar lote mínimo do ativo 
Preço inválido (v<3.29) Tick size não 
respeitado 
Atualizar para v3.29 
8.2 Grade Desaparece Após Reinicialização 
Causa 
Solução 
IniciarGradeAnterior = false 
Configurar como true para retomar grade do 
CSV 
CSV deletado ou corrompido 
Grade precisará ser recriada 
MagicNumber alterado 
EA procura CSV com nome novo — não 
encontra 
© 2025 Trading Expert  |  Página 22 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
8.3 Break Even / Trailing Loss Não Ativa 
Causa 
Solução 
UtilizarBreakEven = false 
Habilitar o parâmetro 
BreakEvenValor = 0 
Configurar valor positivo em R$ 
PrejuizoMaximo = 0 
Break Even exige PrejuizoMaximo < 0 para 
funcionar 
Trailing sem Break Even ativado 
Trailing só funciona após o Break Even ser 
ativado 
8.4 Sincronização Pós-Reconexão 
Sintoma 
Causa 
Solução 
Array diverge do book 
Deals durante 
desconexão não 
processados 
Verificar se sincronização rodou 
(v3.25 informa no painel) 
Ordens duplicadas 
Timestamp incorreto 
v3.23 corrige — atualizar versão 
Sincronização não 
rodou 
emDesconexao não 
detectado 
Ativar ModoDebug e verificar Journal 
8.5 Ordens com Preço Inválido 
Em ativos como WIN e WDO com tick size = 5, configurações com K ou J podem gerar preços não
múltiplos do tick (ex: 123.453). 
• Versões < v3.26: Erro 'preço inválido' no Journal ao tentar criar a ordem 
• v3.26: Preços arredondados automaticamente para o tick size — problema corrigido 
Para verificar o tick size do ativo: 
MT5 → Especificações do contrato → 'Tamanho do tick' 
8.6 Uso do ModoDebug 
Ative ModoDebug = true para registrar no Journal: 
• Criação e cancelamento de ordens 
• Execução de deals (parcial ou completa) 
• Processo de sincronização pós-reconexão 
• Cálculos de Break Even e Trailing Loss 
• Salvamento e carregamento do CSV 
Acesse: MT5 → Caixa de Ferramentas (Ctrl+T) → Aba 'Experts' 
© 2025 Trading Expert  |  Página 23 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
8.7 Estoque Máximo / Stop de Proteção 
Sintoma 
Causa 
Stop de proteção não aparece EstoqueMaximo = 0 
Stop não atualiza ao executar 
nova ordem 
Stop é executada e estoque 
ainda alto 
Stop cancelada 
inesperadamente 
Grade chegou ao fim 
Grade muito ampla 
Estoque caiu abaixo do limite 
8.8 Cooldown Após Stop Loss 
Sintoma 
Causa 
Cooldown não ativa após stop AcaoAposStopLoss != 
ACAO_STOP_COOLDOWN 
EA desativou após poucos 
stops 
Pausa muito longa 
Painel mostra cooldown mas 
EA não retoma 
Quero cancelar o cooldown 
manualmente 
EA não cria nova grade ao 
retomar 
MaxTentativasConsecutivas 
atingido 
Backoff dobra a cada stop 
Cooldown ainda não expirou 
— 
ReusarGradeAposPausa = 
true mas sem CSV válido 
9. REFERÊNCIA TÉCNICA 
Solução 
Configurar valor positivo (ex.: 
metade do tamanho da grade). 
Sem mais ordens na grade — 
Stop não é recriada. Use 
grade maior. 
Reduza distâncias ou aumente 
EstoqueMaximo. 
Comportamento esperado — 
será recriada quando o 
estoque subir. 
Solução 
Configurar AcaoAposStopLoss 
= 
ACAO_STOP_COOLDOWN. 
Aumentar 
MaxTentativasConsecutivas 
se aceitar mais tentativas. 
Reduzir PausaInicialMinutos 
ou aceitar — é proteção contra 
mercado adverso. 
Aguardar até inicioCooldown + 
tempoCooldownSegundos. 
Clique 'Iniciar Operações' — 
zera o cooldown e o contador 
de tentativas. 
Verificar se o CSV existe e 
está íntegro. 
9.1 Arquitetura do EA 
┌──────────────────────────────────────────────────────┐ 
│                    MT5 (Book)                        │ 
│          BUY  extrema  |  SELL  extrema              │ 
└──────────────────────────────────────────────────────┘ 
↕ Sincronização 
┌──────────────────────────────────────────────────────┐ 
│               MEMÓRIA (Array)                        │ 
│  struct OriginalOrderInfo {                          │ 
│     ulong  ticket;                                   │ 
│     double originalPrice;                           │ 
│     double volume;                                   │ 
│     ENUM_ORDER_TYPE orderType;                       │ 
│     string comment;                                  │ 
│  }                                                   │ 
└──────────────────────────────────────────────────────┘ 
↕ Persistência 
┌──────────────────────────────────────────────────────┐ 
│               DISCO (CSV + Backup)                   │ 
│   SYMBOL_MAGIC_Grade.csv                            │ 
│   
SYMBOL_MAGIC_Grade_BKP_YYYYMMDD_HHMMSS.csv       │ 
└──────────────────────────────────────────────────────┘ 
© 2025 Trading Expert  |  Página 24 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
© 2025 Trading Expert  |  Página 25 de 29 
 
9.2 Funções Principais 
Função Descrição 
CriarGradeInicialCompleta() Cria grade do zero com base nos parâmetros 
InserirOrdensExtremas() Mantém as 2 ordens extremas ativas no MT5 
(otimizado v3.11) 
OnTradeTransaction() Processa cada deal: parcial ou completo 
SincronizarComServidor() Reconcilia array com HistoryDeals pós
reconexão 
VerificarMetaLucroPrejuizo() Verifica lucro/prejuízo e aciona Break Even / 
Trailing 
ArredondarPreco() Arredonda preço para tick size do ativo (v3.26) 
BackupCSV() Cria backup do CSV com timestamp (v3.25) 
SalvarEstadoGrade() Salva array completo no CSV 
CarregarGradeDoCSV() Lê CSV e reconstrói o array 
AdicionarOrdemAoArray() Adiciona ou consolida ordem no array (v3.10) 
ExecutarAcaoMeta() Executa ação ao atingir meta (fechar/recriar) 
InserirOrdemStop() Insere ordem Stop de proteção no ponto médio 
entre última executada e próxima pendente (v3.28) 
CancelarOrdemStop() Cancela a ordem Stop de proteção quando o 
estoque volta abaixo do limite (v3.28) 
ContarPosicoesAbertas() Conta as posições abertas do EA (filtra por 
MagicNumber em HEDGE) (v3.28) 
EntrarCooldown() Ativa pausa com backoff exponencial após stop 
loss; desativa o EA ao esgotar tentativas (v3.29) 
VerificarCooldown() Verifica em OnTimer/OnTick se o cooldown 
expirou e retoma operações (v3.29) 
ContarOrdensDoEA() Conta ordens pendentes deste EA no book — 
usado para verificação de integridade (v3.27) 
 
  
Gradient Grid EA v3.26  |  Documentação do Usuário 
© 2025 Trading Expert  |  Página 26 de 29 
 
9.3 Variáveis Globais de Estado 
Variável Tipo Descrição 
robotAtivo bool EA está ativo ou não 
metaAtingidaHoje bool Bloqueia reativação automática após 
meta (v3.15) 
ultimoResetLucroPrejuizo datetime Timestamp do último reset de lucro 
(v3.21) 
ultimaSincronizacao datetime Última vez que sincronização rodou 
(v3.22) 
emDesconexao bool EA estava desconectado do servidor 
(v3.22) 
timestampDesconexao datetime Momento exato da desconexão 
(v3.23) 
breakEvenAtivado bool Break Even já foi ativado (v3.22) 
prejuizoDinamico double Piso atual de lucro garantido (v3.22) 
nivelBaseTrailing double Lucro base para cálculo do Trailing 
Loss (v3.22) 
isHedge bool Tipo de conta: true=HEDGE, 
false=NETTING (v3.21) 
ticketOrdemStop ulong Ticket da ordem Stop de proteção ativa 
(0 = nenhuma) (v3.28) 
emCooldown bool EA está em pausa após stop loss 
(v3.29) 
inicioCooldown datetime Momento do início do cooldown atual 
(v3.29) 
tentativaAtual int Contador de stop losses consecutivos 
no dia (v3.29) 
tempoCooldownSegundos int Duração do cooldown corrente em 
segundos (v3.29) 
 
9.4 Fluxo de Eventos 
OnInit(): 
   → Detecta tipo de conta (HEDGE/NETTING) 
   → Inicializa variáveis 
   → Se StatusInicial=ATIVO: ativa e cria/carrega grade 
 
OnTick(): 
   → Verifica horário de início (se InicioAutomatico) 
   → Verifica horário de fechamento 
   → Verifica meta de lucro/prejuízo 
   → Atualiza painel L/P 
 
OnTradeTransaction() [deal executado]: 
   → Identifica deal por MagicNumber + Symbol 
   → Verifica se parcial ou completa 
   → Atualiza array 
Gradient Grid EA v3.26  |  Documentação do Usuário 
→ Salva CSV 
→ InserirOrdensExtremas() 
OnTimer() [1s]: 
→ Detecta reconexão → SincronizarComServidor() 
→ Atualiza label L/P 
OnDeinit(): 
→ Salva CSV 
→ Cria backup CSV (v3.25) 
© 2025 Trading Expert  |  Página 27 de 29 
Gradient Grid EA v3.26  |  Documentação do Usuário 
© 2025 Trading Expert  |  Página 28 de 29 
10. GLOSSÁRIO 
10.1 Termos do EA 
Termo Definição 
Grade Parcial Estratégia de manter apenas 2 ordens no MT5 enquanto o 
restante está em memória 
Ordem Extrema A ordem mais distante do preço atual em cada lado (BUY 
maior / SELL menor) 
Gain Ordem oposta criada após execução, calculada a GainPips 
do preço original 
Consolidação Soma dos volumes de ordens do mesmo tipo/preço no 
mesmo slot do array 
Tick Size Menor variação válida de preço para um ativo (ex: WIN = 5 
pts, EURUSD = 0.00001) 
Break Even Ponto a partir do qual o piso de perda é zerado — lucro 
garantido em zero 
Trailing Loss Stop móvel de lucro: à medida que o lucro sobe, o piso 
sobe junto 
Sincronização Processo de reconciliar o array interno com deals 
executados no servidor 
MagicNumber Número identificador único que separa as ordens deste EA 
de outros 
Piso Dinâmico Valor mínimo de lucro garantido, atualizado pelo Trailing 
Loss 
Arredondamento Tick Ajuste automático do preço para múltiplo do tick size 
(v3.26) 
CSV Backup Cópia do arquivo de grade criada com timestamp ao 
desativar o EA (v3.25) 
Estoque Máximo Limite de posições simultâneas; ao ser atingido, o EA insere 
uma ordem Stop de proteção (v3.28) 
Stop de Proteção Ordem Stop inserida no ponto médio entre a última ordem 
executada e a próxima pendente, com volume = ordem 
seguinte (v3.28) 
Cooldown Pausa temporária após stop loss antes de retomar 
operações; bloqueia sincronização e processamento de 
deals (v3.29) 
Backoff Exponencial Estratégia em que o tempo de pausa dobra a cada nova 
tentativa (30 → 60 → 120 minutos) (v3.29) 
 
  
Gradient Grid EA v3.26  |  Documentação do Usuário 
10.2 Siglas 
Sigla 
Significado 
EA 
Expert Advisor — robô de trading no MT5 
MT5 
MetaTrader 5 — plataforma de negociação 
BID 
Melhor preço de compra no book de ofertas 
ASK 
Melhor preço de venda no book de ofertas 
CSV 
Comma-Separated Values — formato de arquivo de texto tabular 
HEDGE 
Tipo de conta que permite múltiplas posições opostas 
NETTING 
Tipo de conta que consolida posições opostas em uma só 
J 
Multiplicador de volume progressivo 
K 
Multiplicador de distância progressiva 
B3 
Brasil, Bolsa, Balcão — bolsa de valores brasileira 
WIN 
Mini-contrato de Índice Bovespa negociado na B3 
WDO 
Mini-contrato de Dólar negociado na B3 
�
�  FIM DA DOCUMENTAÇÃO  🎉 
Gradient Grid EA v3.29  |  © 2025-2026 Trading Expert 
© 2025 Trading Expert  |  Página 29 de 29 

Gradient Grid EA v3.26  |  Documentação do Usuário 

# **GRADIENT GRID EA v3.29** 

Documentação Técnica do Usuário 

Plataforma: MetaTrader 5     |     Autor: Trading Expert     |     Maio 2026 

© 2025 Trading Expert  |  Página 1 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **Índice** 

```
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
```

© 2025 Trading Expert  |  Página 2 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **1. INTRODUÇÃO** 

### **1.1 Visão Geral** 

O Gradient Grid EA v3.29 é um Expert Advisor (robô de trading) para MetaTrader 5 que opera utilizando a estratégia de grade simétrica com gradiente progressivo. 

##### **Conceito Principal:** 

- Cria uma 'escada' de ordens de compra (BUY_LIMIT) abaixo do BID 

- Cria uma 'escada' de ordens de venda (SELL_LIMIT) acima do BID 

- Quando uma ordem é executada, cria automaticamente uma ordem oposta (gain) 

- Mantém a grade funcionando continuamente 

- Referência: BID (melhor preço de compra no book de ofertas) 

### **1.2 Características Principais** 

#### **Grade Parcial Otimizada** 

- Apenas 2 ordens no MT5 por vez (1 BUY + 1 SELL) 

- Grade completa armazenada em memória e arquivo CSV 

- Performance superior e sem rejeições da corretora 

- Atualização automática das ordens extremas 

- Consolidação inteligente de ordens (v3.10): ordens do mesmo tipo/preço são automaticamente mescladas 

#### **Multiplicadores Progressivos** 

- K (Distância): Aumenta progressivamente a distância entre ordens 

- J (Volume): Aumenta progressivamente o volume das ordens 

- Permite estratégias de escala e gerenciamento de risco 

- v3.26: Arredondamento automático de preços para o tick size do ativo 

#### **Persistência de Grade** 

- Salva estado da grade em arquivo CSV 

- Permite reiniciar EA mantendo grade anterior 

- Sobrevive a reinicializações e quedas de conexão 

- v3.25: Backup automático do CSV ao desativar o EA 

#### **Controle de Lucro/Prejuízo (HEDGE e NETTING)** 

- Define meta de lucro (R$) 

- Define limite de prejuízo (R$) 

- Ações automáticas ao atingir metas 

- HEDGE: Filtra posições por MagicNumber 

- NETTING: Usa posição consolidada do símbolo (v3.21+) 

#### **Break Even e Trailing Loss Dinâmico (v3.23/v3.24)** 

- Break Even por Valor (R$): Quando lucro atinge valor configurado, limite de prejuízo é zerado 

- Trailing Loss: A cada R$X de avanço do lucro, o piso de lucro garantido sobe R$X 

- Proteção dinâmica de lucro sem intervenção manual 

© 2025 Trading Expert  |  Página 3 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

#### **Sincronização Inteligente (v3.22/v3.23)** 

- Reconstrói o array de ordens usando HistoryDeals após reconexão 

- Detecta e processa execuções ocorridas durante desconexão 

- Janela de sincronização baseada no timestamp exato da desconexão 

#### **Horários Automáticos** 

- Início automático em horário configurado 

- Fechamento automático em horário configurado 

- Tipos de persistência configuráveis 

- Ideal para operações intraday 

#### **Painel de Controle Visual** 

- 4 botões para controle manual 

- Status visual (Ativo/Inativo) 

- Indicador de lucro/prejuízo em tempo real 

- Interface intuitiva 

#### **Estoque Máximo (v3.28 / v3.29)** 

EstoqueMaximo é um limite de VOLUME REAL do ativo (ações, contratos), na mesma unidade dos volumes das ordens da grade 

Quando volume_atual > EstoqueMaximo: dispara ordem a mercado oposta com volume = k + v_próxima 

k = volume_atual - EstoqueMaximo (excedente em volume real) 

v_próxima = volume da próxima ordem da grade no lado acumulador (cria a histerese) 

HEDGE: fecha as posições mais antigas (full ou partial) até cobrir k + v_próxima | NETTING: única ordem a mercado 

Disparada antes de reinserir as extremas, evitando self-match com pendentes do próprio EA 

#### **Cooldown Pós Stop Loss (v3.29)** 

Pausa progressiva ao atingir PrejuizoMaximo, com backoff exponencial (30 → 60 → 120 min) Após N tentativas consecutivas, EA desativa para o restante do dia Opção para reusar a grade anterior ao retomar (ReusarGradeAposPausa) Reativação manual via botão zera o contador de tentativas 

### **1.3 Changelog Resumido** 

Esta seção resume as evoluções entre v3.21 e v3.29. Para histórico completo, veja a Seção 6. 

|**Versão**|**Principal Melhoria**|
|---|---|
|v3.22|Sincronização inteligente pós-reconexão com HistoryDeals; Break<br>Even dinâmico e Trailing Loss|
|v3.23|Break Even e Trailing Loss usam timestamp exato da desconexão;<br>busca de ordem por preço/tipo|
|v3.24|Break Even por Valor (R$) fixo, independente do lucro alvo|
|v3.25|Backup automático do CSV ao desativar o EA; indicação clara de<br>sincronização rodada|
|v3.26|Arredondamento de preços para tick size do ativo (corrige J/K em|



© 2025 Trading Expert  |  Página 4 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Versão**|**Principal Melhoria**|
|---|---|
||ativos como WIN/WDO)|
|v3.27|Verificação do book pós-reconexão: recria ordens extremas se<br>ausentes|
|v3.28|Estoque Máximo: ordem Stop de proteção ao atingir limite de posições|
|v3.29|Cooldown com backoff exponencial após stop loss; ação configurável<br>após PrejuízoMáximo|



© 2025 Trading Expert  |  Página 5 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **2. INSTALAÇÃO E REQUISITOS** 

### **2.1 Requisitos de Sistema** 

##### **Plataforma:** 

- MetaTrader 5 (build 3200 ou superior) 

- Sistema operacional: Windows 7+, Linux (Wine), macOS (Wine) 

##### **Tipo de Conta:** 

- Qualquer tipo (Netting ou Hedging) 

- Funcionalidades de Lucro/Prejuízo: HEDGE e NETTING (v3.21+) 

- HEDGE: Filtra posições por MagicNumber (ideal para múltiplos EAs) 

- NETTING: Usa posição consolidada do símbolo 

##### **Corretora:** 

- Qualquer corretora compatível com MT5 

- Recomendado: Corretoras com spread baixo 

- Testado com: XP, Clear, Modal e similares 

##### **Recursos de Hardware:** 

- Mínimo: 2 GB RAM, processador dual-core 

- Recomendado: 4 GB+ RAM, processador quad-core 

- Conexão: Internet estável (mínimo 1 Mbps) 

### **2.2 Como Instalar** 

1. Localize o arquivo Gradiente_Linear_3_29.ex5 2. Copie para a pasta de EAs do MT5: 

   - `C:\Users\[SEU_USUÁRIO]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\` 

Atalho: No MT5 vá em Arquivo → Abrir Pasta de Dados → MQL5 → Experts 

3. Se você tem o código-fonte (.mq5): abra o MetaEditor (F4), abra o arquivo e compile (F7) 4. No MT5, pressione Ctrl+N para abrir o Navegador, clique com botão direito em 'Expert Advisors' e selecione Atualizar 

5. Arraste o EA para o gráfico do ativo desejado (ex: WIN, WDO, EURUSD) 6. Configure os parâmetros (ver Seção 4) 

7. Marque 'Permitir trading automático' e clique OK 

### **2.3 Verificação** 

- Painel aparece no canto superior esquerdo do gráfico 

- Ícone de robô visível no canto superior direito 

- Status 'Ativo' ou 'Inativo' exibido no painel 

© 2025 Trading Expert  |  Página 6 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **3. PAINEL DE CONTROLE** 

### **3.1 Layout do Painel** 

```
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
```

### **3.2 Botão 'Iniciar Operações'** 

Ativa o EA e cria/carrega a grade. 

- Ativa o EA (robotAtivo = true) 

- Verifica parâmetro IniciarGradeAnterior: 

   - Se TRUE e CSV existe → Carrega grade anterior 

   - Caso contrário → Cria grade nova 

- Cria 2 ordens no MT5 (maior BUY + menor SELL) 

- Status muda para 'Ativo' 

### **3.3 Botão 'Ativar Sem Criar Ordens'** 

Ativa o EA mas NÃO cria nova grade — carrega o CSV e mapeia ordens existentes no book. 

- Útil para retomar operação após reinicialização sem mexer na grade atual 

- EA lê o CSV e sincroniza com ordens que já estão no MT5 (v3.19) 

### **3.4 Botão 'Cancelar Ordens e Desativar'** 

- Desativa o EA 

- Salva estado da grade em CSV 

- v3.25: Cria backup do CSV com timestamp 

- Cancela TODAS as ordens pendentes do EA 

- Posições abertas permanecem 

### **3.5 Botão 'Fechar Pos/Ord e Desativar'** 

- Desativa o EA 

- Cancela TODAS as ordens pendentes 

- Fecha TODAS as posições abertas 

- Zera completamente a operação 

© 2025 Trading Expert  |  Página 7 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **4. CONFIGURAÇÃO DE PARÂMETROS** 

### **4.1 Grupo: Configurações Gerais de Grade** 

#### **KMultiplicadorAcima / KMultiplicadorAbaixo** 

Tipo: double | Padrão: 0.0 

Multiplicador para distância progressiva entre ordens. Fórmula: 

```
Dist_Nova = Dist_Anterior × (1 + K)
```

|**Valor de K**|**Efeito**|
|---|---|
|0.0|Distância fixa entre todas as ordens (grade linear)|
|0.2–0.5|Distância cresce moderadamente (equilíbrio recomendado)|
|1.0|Distância dobra a cada ordem (grade exponencial)|
|> 1.0|Ordens muito espaçadas; usar com critério baseado em<br>volatilidade|



IMPORTANTE (v3.26): Os preços calculados pelo multiplicador K são automaticamente arredondados para o tick size do ativo, garantindo que as ordens sejam aceitas pela corretora mesmo com ativos de tick grande (ex: WIN, WDO). 

### **4.2 Grupo: Configurações Gerais de Volume** 

#### **JMultiplicadorVolumeAcima / JMultiplicadorVolumeAbaixo** 

Tipo: double | Padrão: 0.0 

Multiplicador para volume progressivo das ordens. Fórmula: 

```
Vol_Novo = Vol_Anterior × (1 + J)
```

|**Valor de J**|**Efeito**|
|---|---|
|0.0|Volume fixo em todas as ordens (mais seguro)|
|0.2–0.5|Volume aumenta gradualmente|
|1.0|Volume dobra a cada ordem (Martingale — risco alto!)|



ATENÇÃO: Volume cresce exponencialmente. Use SEMPRE VolumeMaximo quando J > 0. 

#### **VolumeMaximo** 

Tipo: double | Padrão: 0 (sem limite) 

- 0: Sem limite (usa apenas limite da corretora) 

- > 0: Limita o volume máximo por ordem 

### **4.3 Grade Acima do Preço (SELL_LIMIT)** 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|GapInicialAcima|double|50 pips|Distância da 1ª SELL acima do<br>BID|



© 2025 Trading Expert  |  Página 8 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|DistanciaOrdensAcima|double|20 pips|Distância entre ordens SELL|
|QtdOrdensAcima|int|5|Quantidade de ordens SELL|
|AtivarGradeAcima|bool|true|Habilita/desabilita o lado SELL<br>da grade|



### **4.4 Grade Abaixo do Preço (BUY_LIMIT)** 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|GapInicialAbaixo|double|50 pips|Distância da 1ª BUY abaixo do<br>BID|
|DistanciaOrdensAbaixo|double|20 pips|Distância entre ordens BUY|
|QtdOrdensAbaixo|int|5|Quantidade de ordens BUY|
|AtivarGradeAbaixo|bool|true|Habilita/desabilita o lado BUY<br>da grade|



### **4.5 Preço de Referência** 

Tipo: double | Padrão: 0 

- 0: Usa o BID atual do mercado como centro da grade 

- > 0: Usa preço fixo específico como centro — ideal para testes ou entradas em nível técnico 

### **4.6 Volume e Gain** 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|TamanhoLote|double|1|Volume inicial das ordens|
|GainPips|double|100 pips|Distância da ordem oposta<br>(take profit)|



### **4.7 Persistência** 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|Persistencia|enum|DESATIVAR|Ação ao atingir<br>HorarioFechamento|
|HorarioInicio|string|09:00|Horário de ativação automática<br>(HH:MM)|
|InicioAutomatico|bool|true|Ativa EA automaticamente no<br>HorarioInicio|
|HorarioFechamento|string|17:30|Horário para executar ação de<br>persistência|
|IniciarGradeAnterior|bool|false|Carrega grade do CSV ao|



© 2025 Trading Expert  |  Página 9 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
||||iniciar|



##### Opções de Persistência: 

- PERSISTENCIA_MANTER: Não faz nada — EA continua ativo 

- PERSISTENCIA_FECHAR_ORDENS: Cancela ordens e desativa, mantém posições 

- PERSISTENCIA_FECHAR_TUDO: Fecha posições e ordens, desativa EA 

- PERSISTENCIA_DESATIVAR: Apenas desativa EA, mantém ordens e posições 

### **4.8 Configurações Técnicas** 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|Slippage|int|3 pontos|Desvio máximo de preço aceito|
|MagicNumber|int|12345|Identificador único do EA|
|ModoBrasileiro|bool|true|Ajusta cálculos para mercado<br>B3|
|ModoDebug|bool|false|Ativa logs detalhados no<br>Journal|
|StatusInicial|enum|INATIVO|Estado ao inicializar (ATIVO /<br>INATIVO)|



### **4.9 Meta de Lucro/Prejuízo (HEDGE e NETTING)** 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|LucroAlvo|double|0 (desabilitado)|Meta de lucro em<br>R$ para ação<br>automática|
|PrejuizoMaximo|double|0 (desabilitado)|Limite de prejuízo<br>em R$ (valor<br>NEGATIVO!)|
|AcaoAoAtingirMeta|enum|FECHAR_E_DESATIVAR|O que fazer ao<br>atingir lucro ou<br>prejuízo|



##### Opções de AcaoAoAtingirMeta: 

- ACAO_FECHAR_E_DESATIVAR: Fecha posições, cancela ordens e desativa EA 

- ACAO_FECHAR_E_RECRIAR: Fecha posições, cancela ordens e cria nova grade 

### **4.10 Break Even e Trailing Loss** 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|UtilizarBreakEven|bool|false|Habilita o Break Even<br>dinâmico|



© 2025 Trading Expert  |  Página 10 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Parâmetro**|**Tipo**|**Padrão**|**Descrição**|
|---|---|---|---|
|BreakEvenValor|double|0|Lucro (R$) para ativar o<br>Break Even|
|UtilizarTrailingLoss|bool|false|Habilita o Trailing Loss<br>dinâmico|
|TrailingLossValor|double|10.0|Incremento do piso de lucro<br>(R$)|



### **4.11 Estoque Máximo (v3.28 / v3.29)** 

EstoqueMaximo é tratado como LIMITE DE VOLUME REAL do ativo, na mesma unidade dos volumes das ordens da grade (não é contagem de posições). Quando o volume da posição excede esse limite após uma execução, o EA dispara uma ordem a mercado oposta para retornar ao limite, com histerese baseada na próxima ordem pendente da grade. 

**Parâmetro Tipo Padrão Descrição** EstoqueMaximo int 0 (desabilitado) Quantidade máxima de posições simultâneas. 0 desabilita o Stop de proteção. 

#### **Como funciona:** 

Após cada execução, o EA mede o volume total das posições (HEDGE: soma das posições com nosso MagicNumber; NETTING: volume da posição consolidada do símbolo). 

Se volume_atual > EstoqueMaximo, calcula k = volume_atual - EstoqueMaximo (excedente em volume real do ativo). Identifica a próxima ordem pendente do lado acumulador no array da grade e captura seu volume = v_próxima. 

Dispara ordem a mercado oposta com volume total = k + v_próxima (histerese). NETTING: única ordem a mercado reduz a posição consolidada. HEDGE: fecha as posições mais antigas — usa PositionClose para fechar inteiras e PositionClosePartial quando precisa fechar só uma parte — até a soma fechada cobrir exatamente k + v_próxima. 

Importante: a ordem a mercado é enviada ANTES de reinserir as ordens extremas da grade no book — isso evita cancelamento por self-trade contra pendentes do próprio EA na B3. Histerese: após a proteção, o volume fica v_próxima abaixo do limite. Quando a próxima ordem da grade for executada (adicionando v_próxima ao volume), o estoque retorna exatamente ao limite, sem disparar nova proteção. 

Exemplos numéricos (limite/excedente/v_próxima → ordem a mercado): WIN: 20 / 2 / 2 → 4 contratos VALE3 (volumeMin=100): 500 / 200 / 200 → 400 ações Note: tudo na mesma unidade do ativo. Não há multiplicação por volumeMin. As ordens disparadas são marcadas com o comentário MaxInv:<N> e ignoradas pelo fluxo da grade (não geram ordens de gain). 

Recomendação: configure EstoqueMaximo com o volume total máximo que aceita carregar, na mesma unidade das ordens. 

### **4.12 Ação Após Stop Loss / Cooldown (v3.29)** 

Define o que acontece quando o lucro atinge o limite de PrejuizoMaximo (stop loss). Independente da AcaoAoAtingirMeta, este parâmetro permite escolher entre desativar, recriar a grade ou entrar em cooldown com backoff exponencial. 

**Parâmetro Tipo Padrão Descrição** 

© 2025 Trading Expert  |  Página 11 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|AcaoAposStopLoss|enum|ACAO_STOP_DESAT<br>IVAR|Ação ao atingir<br>PrejuizoMaximo:<br>DESATIVAR,<br>RECRIAR ou<br>COOLDOWN.|
|---|---|---|---|
|PausaInicialMinutos|int|30|Duração da primeira<br>pausa (em minutos)<br>no modo cooldown.|
|MaxTentativasConsec<br>utivas|int|3|Após quantos stops<br>consecutivos o EA é<br>desativado para o dia.|
|ReusarGradeAposPau|bool|false|Ao retomar do|
|sa|||cooldown, carrega a<br>grade anterior do CSV<br>em vez de criar nova.|



#### **Opções de AcaoAposStopLoss:** 

ACAO_STOP_DESATIVAR: Fecha tudo, cancela ordens e desativa o EA (mesmo comportamento das versões anteriores). 

ACAO_STOP_RECRIAR: Fecha tudo, cancela ordens e cria uma nova grade imediatamente. ACAO_STOP_COOLDOWN: Fecha tudo e entra em pausa com backoff exponencial; retoma sozinho ao final. 

#### **Backoff Exponencial:** 

A pausa dobra a cada novo stop consecutivo: PausaInicialMinutos × 2^(tentativa−1). Exemplo com PausaInicialMinutos=30 e MaxTentativasConsecutivas=3: Tentativa 1 → pausa de 30 minutos Tentativa 2 → pausa de 60 minutos Tentativa 3 → pausa de 120 minutos Após o 3º stop → EA é desativado para o dia (metaAtingidaHoje = true) Importante: lucro atingido (LucroAlvo) zera o contador de tentativas; reativação manual via botão também reseta o cooldown. 

© 2025 Trading Expert  |  Página 12 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **5. FUNCIONALIDADES AVANÇADAS** 

### **5.1 Grade Parcial (2 Ordens no MT5)** 

A Grade Parcial é a principal inovação da arquitetura v3.x. Em vez de criar todas as ordens no MT5, o EA mantém apenas as 2 extremas ativas: 

```
MT5 (2 ordens reais):
   BUY  100450  |  SELL 100550
MEMÓRIA / CSV (grade completa):
   BUY  100450, 100430, 100410, 100390, 100370
   SELL 100550, 100570, 100590, 100610, 100630
```

Quando uma ordem é executada: 

8. OnTradeTransaction detecta o deal 

9. Array é atualizado (remove executada, adiciona gain) 

10. CSV é salvo imediatamente 

11. InserirOrdensExtremas() atualiza as 2 ordens no MT5 

Vantagens: menor latência, sem rejeições, sincronização simplificada, código mais limpo. 

### **5.2 Multiplicadores Progressivos K e J** 

K (distância) e J (volume) criam grades assimétricas e progressivas. 

##### Exemplo K=0.5 com DistanciaInicial=20 pips: 

```
SELL 100550 (gap=50, dist=0)
SELL 100570 (dist=20)
SELL 100600 (dist=30 → 20×1.5)
SELL 100645 (dist=45 → 30×1.5)
```

|Tabela de<br>|exposição total com<br>|J progressivo (5 ordens, Lote<br>|=1.0):<br>|
|---|---|---|---|
|**J**|**Vol. Total**|**Vol. Máx Individual**|**Exposição vs J=0**|
|0.0|5.0|1.0|1× (base)|
|0.2|7.4|2.1|1.5×|
|0.5|13.3|5.1|2.7×|
|1.0|31.0|16.0|6.2×|



ALERTA: J = 1.0 com 10 ordens = 1.023 contratos sem limite. SEMPRE use VolumeMaximo! 

### **5.3 Persistência de Grade (CSV)** 

O EA salva o estado completo da grade em: 

- `C:\Users\[USUÁRIO]` 

- `\AppData\Roaming\MetaQuotes\Common\Files\SYMBOL_MAGICNUMBER_Grade.csv` 

Estrutura do arquivo (v3.26): 

```
Ticket,Tipo,Preco,Volume,Comentario
54123456,0,100450.000000,1.000000,Grade Inicial
0,2,100550.000000,1.000000,Grade Inicial
```

© 2025 Trading Expert  |  Página 13 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

v3.25 — Backup Automático: Ao desativar o EA via botão ou horário de fechamento, é criado automaticamente um backup com timestamp: 

```
WINM25_12345_Grade_BKP_20250319_173005.csv
```

### **5.4 Break Even Dinâmico (v3.24)** 

Quando o lucro da posição atinge o valor configurado em BreakEvenValor (R$), o limite de prejuízo é automaticamente zerado. 

Exemplo: 

```
PrejuizoMaximo  = -50.0   (limite de perda)
BreakEvenValor  = 30.0    (gatilho)
Lucro chega a R$ 30 → PrejuizoDinamico = 0
Agora o EA só encerra se lucro cair abaixo de R$ 0
```

### **5.5 Trailing Loss Dinâmico (v3.23)** 

Após o Break Even ser ativado, a cada incremento de TrailingLossValor (R$) no lucro, o piso de lucro garantido sobe na mesma proporção. 

Exemplo com TrailingLossValor = 10: 

```
Break Even ativado em R$ 30 → piso = R$ 0
Lucro sobe para R$ 40        → piso = R$ 10
Lucro sobe para R$ 50        → piso = R$ 20
Lucro cai para R$ 15         → EA ENCERRA (lucro < piso R$ 20)
```

### **5.6 Sincronização Inteligente Pós-Reconexão (v3.22/v3.23)** 

Ao detectar reconexão ao servidor, o EA executa SincronizarComServidor() que: 

12. Registra o timestamp exato da desconexão 

13. Consulta HistoryDeals na janela: timestamp_desconexao → agora 

14. Identifica execuções ocorridas durante o período offline 

15. Processa os 4 casos possíveis: 

   - Caso A: Uma ordem completamente executada — remove do array, insere gain 

   - Caso B: Ambas executadas — ciclo completo, mantém array 

   - Caso C: Uma parcialmente executada — atualiza volume, insere gain parcial 

   - Caso D: Ambas parcialmente executadas — calcula líquido e ajusta 

16. Salva CSV atualizado e reinicia as 2 ordens extremas 

v3.25: O painel indica claramente se a sincronização foi executada ou não. 

### **5.7 Controle de Lucro/Prejuízo (HEDGE e NETTING)** 

O EA calcula o lucro total considerando: 

- Lucro flutuante de todas as posições abertas (filtradas por MagicNumber em HEDGE) 

- Lucro de todas as operações fechadas no dia (a partir do início do dia ou do último reset) 

- Swap e comissões incluídos 

##### <u>Comparação HEDGE vs NETTING:</u> 

|**Aspecto**|**HEDGE**|**NETTING**|
|---|---|---|
|Filtro de posições|Por MagicNumber (só deste<br>EA)|Posição consolidada do<br>símbolo|



© 2025 Trading Expert  |  Página 14 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Aspecto**|**HEDGE**|**NETTING**|
|---|---|---|
|Múltiplos EAs|Cada EA controla as suas|Todos veem o mesmo<br>resultado|
|Ideal para|Múltiplos EAs no mesmo ativo|EA único por ativo|



© 2025 Trading Expert  |  Página 15 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

### **5.8 Verificação do Book Pós-Reconexão (v3.27)** 

Após uma reconexão ao servidor MT5, mesmo que a sincronização inteligente (v3.22+) não detecte deals durante o período offline, o EA verifica se as 2 ordens extremas continuam ativas no book. 

#### **Comportamento:** 

Conta as ordens pendentes deste EA no book via ContarOrdensDoEA(). 

Se houver menos de 2 ordens, recria as ordens extremas com base no array em memória. Evita situação em que ordens foram canceladas pela corretora ou pelo servidor durante a desconexão e a grade fica sem cobertura. 

### **5.9 Estoque Máximo — Proteção via Ordem a Mercado (v3.28 / v3.29)** 

O parâmetro EstoqueMaximo define o teto absoluto de volume que a grade pode manter aberto, expresso na mesma unidade dos volumes das ordens (ações para B3 stocks, contratos para futuros). Quando esse teto é excedido após uma execução, o EA dispara uma ordem a mercado oposta que retorna o volume da posição ao limite. A proteção foi reformulada na v3.29 (revisada): a versão original (v3.28) usava ordem Stop pendente, mas em ativos com grade apertada ou tick size grande o Stop era rejeitado pela corretora por violar SYMBOL_TRADE_STOPS_LEVEL, deixando o estoque crescer sem controle. Uma revisão posterior também corrigiu a semântica de EstoqueMaximo: agora é um limite de volume real, não de contagem de posições. 

#### **Fluxo após cada execução da grade:** 

Mede o volume total das posições (HEDGE: soma das posições filtradas por MagicNumber; NETTING: PositionGetDouble(POSITION_VOLUME) da consolidada). 

Se volume_atual > EstoqueMaximo, calcula k = volume_atual - EstoqueMaximo (excedente em volume real do ativo). 

Busca a próxima ordem pendente do lado acumulador no array da grade e captura v_próxima = volume dela. 

Determina o lado da proteção: acumulando comprado → VENDE | acumulando vendido → COMPRA. 

#### **Cálculo do volume total a fechar:** 

volume_total = k + v_próxima  (histerese, na mesma unidade do ativo) 

O termo k retorna o volume da posição exatamente ao limite. O termo v_próxima cria um buffer de uma ordem inteira da grade — quando a próxima pendente for executada, o volume volta ao limite, sem disparar nova proteção imediata. 

Importante: não há multiplicação por volumeMin. EstoqueMaximo, k, v_próxima e o volume da ordem a mercado estão todos na mesma unidade (a mesma unidade dos volumes das ordens da grade). 

#### **Exemplos numéricos:** 

WIN (volumeMin = 1): limite = 20, excedente = 2, v_próxima = 2 → ordem a mercado de 4 contratos. 

VALE3 (volumeMin = 100): limite = 500, excedente = 200, v_próxima = 200 → ordem a mercado de 400 ações. 

#### **Execução em NETTING:** 

Uma única ordem a mercado oposta de volume_total = k + v_próxima reduz a posição consolidada do símbolo. 

#### **Execução em HEDGE:** 

Itera fechando posições mais antigas (uma a uma, pelo POSITION_TIME). Para cada posição, se a soma fechada + volume_da_posição ainda for ≤ volume_total, fecha inteira com 

© 2025 Trading Expert  |  Página 16 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

PositionClose(ticket). Caso contrário, fecha apenas o restante com PositionClosePartial(ticket, restante). Para quando soma_fechada ≥ volume_total. 

Esse mecanismo garante o fechamento exato do alvo, sem over-close, mesmo quando as posições mais antigas têm volumes desiguais (grades com J ativo). 

#### **Ordem das operações (crítico para B3):** 

A proteção é disparada ANTES da rotina InserirOrdensExtremas reposicionar as pendentes no book. Esse detalhe é essencial em corretoras B3 com prevenção de self-trade: se as novas pendentes do EA já estiverem ativas, a ordem a mercado é silenciosamente cancelada pelo broker (auto-execução do mesmo MagicNumber). 

#### **Tag de identificação:** 

As ordens disparadas pela proteção carregam o comentário MaxInv:<N>. O OnTradeTransaction reconhece esse comentário, registra o deal no log e ignora o fluxo de gain — assim a proteção não cria ordens fantasmas na grade. 

#### **Log esperado quando aciona:** 

ESTOQUE MÁXIMO EXCEDIDO! Aplicando proteção (NETTING|HEDGE) Volume atual: V / Máximo: M (excedente k = K) Volume da próxima ordem da grade: P Volume a mercado: W (= k + v_próxima) Lado: VENDA | COMPRA Ordem a mercado enviada. Ticket: #... Volume agora: V' / Máximo: M 

### **5.10 Cooldown com Backoff Exponencial (v3.29)** 

Quando AcaoAposStopLoss = ACAO_STOP_COOLDOWN e o EA atinge o limite de PrejuizoMaximo, em vez de desativar imediatamente o EA pausa por um tempo configurável e tenta novamente. 

Cada novo stop dobra a duração da pausa (backoff exponencial). Após esgotar MaxTentativasConsecutivas, o EA é desativado para o restante do dia (metaAtingidaHoje = true). 

#### **Fluxo:** 

PrejuizoMaximo atingido → tentativaAtual++ → entra em cooldown. Cancela todas as ordens pendentes e fecha todas as posições. Aguarda PausaInicialMinutos × 2^(tentativaAtual−1) minutos. 

Ao final, recria a grade (ou carrega a anterior se ReusarGradeAposPausa = true) e retoma operações. 

#### **Resets:** 

LucroAlvo atingido zera tentativaAtual (após uma vitória, recomeça a contagem). Reativação manual via botão 'Iniciar Operações' também zera tentativaAtual e o cooldown. Mudança de dia zera tentativaAtual e o cooldown. 

#### **Painel:** 

Durante o cooldown, o painel exibe 'EM COOLDOWN' e o tempo restante em minutos, junto da contagem de tentativas (ex: 2/3). 

Durante o cooldown, a sincronização pós-reconexão e o processamento de novos deals são bloqueados, evitando que o EA reabra posições enquanto está pausado. 

## **6. NOVIDADES DA v3.22 À v3.29** 

© 2025 Trading Expert  |  Página 17 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

### **v3.29 — Cooldown com Backoff Exponencial Após Stop Loss** 

Principal novidade desta versão. Permite ao EA reagir de forma escalonada ao atingir o limite de prejuízo, em vez de simplesmente desativar. 

#### **Novo enum ENUM_ACAO_STOP com três opções:** 

ACAO_STOP_DESATIVAR: comportamento padrão das versões anteriores — fecha tudo e desativa. 

ACAO_STOP_RECRIAR: fecha tudo e cria nova grade imediatamente. 

ACAO_STOP_COOLDOWN: pausa com backoff exponencial e retoma operações ao final. Novos parâmetros: AcaoAposStopLoss, PausaInicialMinutos, MaxTentativasConsecutivas, ReusarGradeAposPausa. 

Backoff: a pausa dobra a cada nova tentativa (30 → 60 → 120 min). Após esgotar tentativas, EA desativa para o dia. 

Resets automáticos: lucro atingido, reativação manual e mudança de dia zeram o contador. 

### **v3.28 / v3.29 — Estoque Máximo (Ordem a Mercado com Histerese)** 

v3.28 introduziu o controle de estoque via Stop pendente; v3.29 (revisada) substituiu o Stop por ordem a mercado com histerese, eliminando rejeições por SYMBOL_TRADE_STOPS_LEVEL e self-trade na B3. Uma revisão posterior corrigiu a semântica: EstoqueMaximo agora é um limite de VOLUME REAL do ativo (na mesma unidade dos volumes das ordens), não uma contagem de posições. 

Parâmetro: EstoqueMaximo (int, 0 = desabilitado). Unidade: a mesma dos volumes das ordens (ações, contratos). 

Detecção: após cada execução, se volume_atual > EstoqueMaximo. 

Cálculo: volume a mercado = k + v_próxima (k = volume_atual - EstoqueMaximo; v_próxima = volume da próxima ordem da grade no lado acumulador). 

NETTING: ordem a mercado oposta única, reduz a consolidada. 

HEDGE: fecha posições mais antigas (PositionClose ou PositionClosePartial) até cobrir exatamente k + v_próxima. 

Ordem disparada ANTES de InserirOrdensExtremas para evitar cancelamento por self-trade contra pendentes do próprio EA. 

Tag MaxInv:<N> no comentário das ordens de proteção; OnTradeTransaction ignora esses deals no fluxo da grade. 

Histerese garante que a próxima execução da grade traga o volume exatamente ao limite, sem ping-pong de proteção. 

Compatibilidade: para ativos com volumeMin = 1 (WIN, WDO) o comportamento permanece idêntico. Para ativos com volumeMin > 1 (ações, opções) o EstoqueMaximo agora é interpretado corretamente em volume real. 

### **v3.27 — Verificação do Book Pós-Reconexão** 

Adiciona verificação de integridade do book após reconexão ao servidor. Se a sincronização não encontrou deals no período offline mas o book contém menos de 2 ordens extremas, o EA recria as ordens com base no array em memória. 

Resolve o caso em que a corretora ou o servidor cancela ordens durante a desconexão sem registrar deals correspondentes. 

Garante que a grade sempre permaneça com cobertura ativa após qualquer reconexão. 

### **v3.26 — Arredondamento por Tick Size** 

Principal novidade desta versão. Todos os preços calculados pelo EA (grade inicial, ordens de gain, sincronização) são agora automaticamente arredondados para o tick size do ativo antes de serem enviados ao MT5. 

© 2025 Trading Expert  |  Página 18 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

##### Nova função ArredondarPreco(): 

```
double ArredondarPreco(double preco) {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      preco = MathRound(preco / tickSize) * tickSize;
   return NormalizeDouble(preco, _Digits);
}
```

##### Esta correção é especialmente importante para: 

- Ativos da B3 como WIN e WDO onde o tick size é 5 pontos 

- Configurações com multiplicador J alto, que geram preços não-múltiplos do tick 

- Configurações com multiplicador K em distâncias não-múltiplas do tick 

Impacto: Elimina erros de 'preço inválido' ao criar ordens em ativos com tick size > 1 ponto. 

### **v3.25 — Backup Automático do CSV** 

- Ao desativar o EA (via botão 'Cancelar Ordens e Desativar', horário de fechamento ou OnDeinit), um backup do CSV é criado automaticamente com data e hora no nome 

- Formato: SYMBOL_MAGIC_Grade_BKP_AAAAMMDD_HHMMSS.csv 

- Útil para auditoria, recuperação de grades antigas ou comparação de estados 

- O backup não substitui o arquivo principal — ambos coexistem 

### **v3.25 — Sincronização com Indicação Clara** 

- O painel exibe mensagem diferenciada conforme sincronização foi executada ou não 

- • Facilita diagnóstico após reconexão 

### **v3.24 — Break Even por Valor (R$)** 

- Novo parâmetro BreakEvenValor: define um valor fixo em R$ para ativar o Break Even, independente de qualquer percentual do lucro alvo 

- Complementa UtilizarBreakEven (bool) e é mais intuitivo para traders de ativos brasileiros 

- Quando lucro >= BreakEvenValor: prejuizoDinamico = 0 (piso zerado) 

- O nível base para o Trailing Loss é definido neste momento 

### **v3.23 — Trailing Loss e Fix de Sincronização** 

- Trailing Loss: A cada TrailingLossValor (R$) de avanço do lucro após Break Even, o piso de lucro garantido sobe no mesmo valor — nunca desce 

- Fix de Sincronização: A janela de busca de HistoryDeals usa agora o timestamp exato da desconexão (não a última sincronização), evitando deals duplicados 

- Nova função EncontrarOrdemPorPrecoETipo() para uso durante a sincronização 

### **v3.22 — Sincronização Inteligente** 

- OnTimer passa a detectar reconexão (retorno de emDesconexao = true para false) 

- SincronizarComServidor() reconstrói o array com base no HistoryDeals do período offline 

- Variáveis de controle: ultimaSincronizacao, emDesconexao, timestampDesconexao 

- Reinicia Break Even e Trailing Loss ao recriar grade (ACAO_FECHAR_E_RECRIAR) 

© 2025 Trading Expert  |  Página 19 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Versão**|**Funcionalidade**|**Impacto**|
|---|---|---|
|v3.26|Arredondamento por tick size|Crítico — corrige criação de ordens<br>em ativos B3|
|v3.25|Backup automático CSV|Segurança — preserva histórico de<br>grades|
|v3.25|Indicação de sincronização|UX — diagnóstico mais rápido|
|v3.24|Break Even por valor R$|Proteção — gatilho mais preciso|
|v3.23|Trailing Loss dinâmico|Proteção — piso de lucro<br>progressivo|
|v3.23|Fix timestamp desconexão|Robustez — sincronização sem<br>duplicatas|
|v3.22|Sincronização pós-reconexão|Robustez — recuperação<br>automática|
|v3.27|Verificação do book pós-reconexão|Robustez — repõe ordens extremas<br>após desconexão|
|v3.28|Estoque Máximo (Stop de proteção)|<br>Proteção — limita exposição máxima<br>da grade|
|v3.29|Cooldown após stop loss|<br>Proteção — pausa progressiva contra<br>perdas em série|



© 2025 Trading Expert  |  Página 20 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **7. EXEMPLOS DE CONFIGURAÇÃO** 

### **7.1 Grade Padrão Intraday (WIN)** 

Configuração conservadora para mini-índice, operação intraday: 

```
GapInicialAcima      = 50
DistanciaOrdensAcima = 20
QtdOrdensAcima       = 5
AtivarGradeAcima     = true
```

```
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
```

### **7.2 Grade com Gradiente (K=0.3)** 

Grade com distâncias crescentes — captura movimentos maiores sem expor muito nos extremos: `KMultiplicadorAcima  = 0.3 KMultiplicadorAbaixo = 0.3 DistanciaOrdensAcima  = 20 DistanciaOrdensAbaixo = 20 GainPips             = 60` 

### **7.3 Grade com Volume Progressivo (J=0.3)** 

Volume aumenta 30% a cada ordem. SEMPRE com VolumeMaximo: 

```
JMultiplicadorVolumeAcima  = 0.3
JMultiplicadorVolumeAbaixo = 0.3
TamanhoLote               = 1
VolumeMaximo              = 3
```

### **7.4 Com Meta e Break Even** 

Encerra com lucro e protege com Break Even + Trailing Loss: 

```
LucroAlvo             = 200.0
PrejuizoMaximo        = -50.0
AcaoAoAtingirMeta     = FECHAR_E_DESATIVAR
UtilizarBreakEven     = true
BreakEvenValor        = 60.0      // Ativa ao ganhar R$ 60
UtilizarTrailingLoss  = true
TrailingLossValor     = 15.0      // Piso sobe R$ 15 a cada R$ 15 de ganho
```

### **7.5 Grade Apenas BUY (Tendência de Baixa)** 

Operar apenas o lado da compra — grade assimétrica: 

```
AtivarGradeAcima  = false
AtivarGradeAbaixo = true
GapInicialAbaixo      = 50
```

© 2025 Trading Expert  |  Página 21 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

```
DistanciaOrdensAbaixo = 30
QtdOrdensAbaixo       = 8
```

### **7.6 Reinício com Grade Anterior** 

Para retomar exatamente de onde parou após reinicialização: 

```
IniciarGradeAnterior = true
StatusInicial        = INATIVO
InicioAutomatico     = true
```

© 2025 Trading Expert  |  Página 22 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

### **7.7 Com Estoque Máximo e Cooldown** 

Configuração que limita exposição e usa cooldown progressivo após stops: EstoqueMaximo            = 5 LucroAlvo                = 200.0 PrejuizoMaximo           = -100.0 AcaoAposStopLoss         = ACAO_STOP_COOLDOWN PausaInicialMinutos      = 30 MaxTentativasConsecutivas = 3 ReusarGradeAposPausa     = false 

Comportamento esperado: ao atingir 5 posições, Stop de proteção é inserida. Ao atingir prejuízo de R$ 100, EA pausa 30 min e tenta de novo. No 2º stop, pausa 60 min. No 3º, pausa 120 min. No 4º, EA desativa para o dia. 

## **8. TROUBLESHOOTING** 

### **8.1 EA Não Cria Ordens** 

|**Sintoma**|**Causa Provável**|**Solução**|
|---|---|---|
|Painel mostra 'Inativo'|EA não foi ativado|Clique 'Iniciar Operações'|
|Erro no Journal|Trading automático<br>desabilitado|Habilitar 'Permitir trading automático'<br>no MT5|
|Lote inválido|TamanhoLote abaixo<br>do mínimo|Verificar lote mínimo do ativo|
|Preço inválido (v<3.29)|Tick size não<br>respeitado|Atualizar para v3.29|



### **8.2 Grade Desaparece Após Reinicialização** 

|**Causa**|**Solução**|
|---|---|
|IniciarGradeAnterior = false|Configurar como true para retomar grade do<br>CSV|
|CSV deletado ou corrompido|Grade precisará ser recriada|
|MagicNumber alterado|EA procura CSV com nome novo — não<br>encontra|



### **8.3 Break Even / Trailing Loss Não Ativa** 

|**Causa**|**Solução**|
|---|---|
|UtilizarBreakEven = false|Habilitar o parâmetro|
|BreakEvenValor = 0|Configurar valor positivo em R$|
|PrejuizoMaximo = 0|Break Even exige PrejuizoMaximo < 0 para<br>funcionar|
|Trailing sem Break Even ativado|Trailing só funciona após o Break Even ser|



© 2025 Trading Expert  |  Página 23 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Causa**|**Solução**|
|---|---|
||ativado|



### **8.4 Sincronização Pós-Reconexão** 

|**Sintoma**|**Causa**|**Solução**|
|---|---|---|
|Array diverge do book|Deals durante<br>desconexão não<br>processados|Verificar se sincronização rodou<br>(v3.25 informa no painel)|
|Ordens duplicadas|Timestamp incorreto|v3.23 corrige — atualizar versão|
|Sincronização não<br>rodou|emDesconexao não<br>detectado|Ativar ModoDebug e verificar Journal|



### **8.5 Ordens com Preço Inválido** 

Em ativos como WIN e WDO com tick size = 5, configurações com K ou J podem gerar preços nãomúltiplos do tick (ex: 123.453). 

   - Versões < v3.26: Erro 'preço inválido' no Journal ao tentar criar a ordem 

- v3.26: Preços arredondados automaticamente para o tick size — problema corrigido 

- Para verificar o tick size do ativo: 

```
MT5 → Especificações do contrato → 'Tamanho do tick'
```

### **8.6 Uso do ModoDebug** 

Ative ModoDebug = true para registrar no Journal: 

- Criação e cancelamento de ordens 

- Execução de deals (parcial ou completa) 

- Processo de sincronização pós-reconexão 

- Cálculos de Break Even e Trailing Loss 

- Salvamento e carregamento do CSV 

Acesse: MT5 → Caixa de Ferramentas (Ctrl+T) → Aba 'Experts' 

© 2025 Trading Expert  |  Página 24 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

### **8.7 Estoque Máximo / Proteção a Mercado** 

|Sintoma|Causa|Solução|
|---|---|---|
|Proteção não atua|EstoqueMaximo = 0|Configurar valor positivo (em<br>volume real do ativo).|
|EstoqueMaximo configurado|Confusão de unidade:|Para VALE3,|
|mas estoque cresce muito|EstoqueMaximo é volume real,<br>não 'lotes padrão'|EstoqueMaximo=500 significa<br>500 ações (= 5 lotes padrão).<br>Para WIN, 20 significa 20<br>contratos.|
|Volume ultrapassa o limite e<br>fica preso|Mercado muito rápido; várias<br>execuções em sequência|Próxima execução já dispara a<br>proteção. Confira o log<br>'ESTOQUE MÁXIMO<br>EXCEDIDO'.|
|Log mostra ordem enviada<br>mas volume não reduz|Self-trade: pendentes do EA<br>no book|Confirme que a versão é v3.29<br>(revisada) — a proteção é<br>disparada ANTES de<br>InserirOrdensExtremas.|
|Sem próxima ordem na grade<br>para histerese|Grade chegou ao fim|Sem buffer; proteção fecha<br>apenas o excedente (k).<br>Aumente|
|||OrderCountAbove/Below ou<br>ajuste EstoqueMaximo.|
|HEDGE: posição antiga não|Falha no|Verifique permissões de|
|fecha|PositionClose/PartialClose<br>(erro no log)|trading; revise log com<br>retcode.|
|Quero auditar as ordens de<br>proteção|—|Filtre o histórico por<br>comentário começando com<br>MaxInv:|



### **8.8 Cooldown Após Stop Loss** 

|**Sintoma**|**Causa**|**Solução**|
|---|---|---|
|Cooldown não ativa após stop|AcaoAposStopLoss !=<br>ACAO_STOP_COOLDOWN|Configurar AcaoAposStopLoss<br>=<br>ACAO_STOP_COOLDOWN.|
|EA desativou após poucos<br>stops|MaxTentativasConsecutivas<br>atingido|Aumentar<br>MaxTentativasConsecutivas<br>se aceitar mais tentativas.|
|Pausa muito longa|Backoff dobra a cada stop|Reduzir PausaInicialMinutos<br>ou aceitar — é proteção contra<br>mercado adverso.|
|Painel mostra cooldown mas<br>EA não retoma|Cooldown ainda não expirou|Aguardar até inicioCooldown +<br>tempoCooldownSegundos.|
|Quero cancelar o cooldown<br>manualmente|—|Clique 'Iniciar Operações' —<br>zera o cooldown e o contador<br>de tentativas.|
|EA não cria nova grade ao<br>retomar|ReusarGradeAposPausa =<br>true mas sem CSV válido|Verificar se o CSV existe e<br>está íntegro.|



## **9. REFERÊNCIA TÉCNICA** 

### **9.1 Arquitetura do EA** 

```
┌──────────────────────────────────────────────────────┐
```

© 2025 Trading Expert  |  Página 25 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

```
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
│   SYMBOL_MAGIC_Grade_BKP_YYYYMMDD_HHMMSS.csv       │
└──────────────────────────────────────────────────────┘
```

### **9.2 Funções Principais** 

|**Função**|**Descrição**|
|---|---|
|CriarGradeInicialCompleta()|Cria grade do zero com base nos parâmetros|
|InserirOrdensExtremas()|Mantém as 2 ordens extremas ativas no MT5<br>(otimizado v3.11)|
|OnTradeTransaction()|Processa cada deal: parcial ou completo|
|SincronizarComServidor()|Reconcilia array com HistoryDeals pós-<br>reconexão|
|VerificarMetaLucroPrejuizo()|Verifica lucro/prejuízo e aciona Break Even /<br>Trailing|
|ArredondarPreco()|Arredonda preço para tick size do ativo (v3.26)|
|BackupCSV()|Cria backup do CSV com timestamp (v3.25)|
|SalvarEstadoGrade()|Salva array completo no CSV|
|CarregarGradeDoCSV()|Lê CSV e reconstrói o array|
|AdicionarOrdemAoArray()|Adiciona ou consolida ordem no array (v3.10)|
|ExecutarAcaoMeta()|Executa ação ao atingir meta (fechar/recriar)|
|ContarPosicoesAbertas()|Conta as posições abertas do EA (filtra por<br>MagicNumber em HEDGE) (v3.28)|
|EntrarCooldown()|Ativa pausa com backoff exponencial após stop<br>loss; desativa o EA ao esgotar tentativas (v3.29)|
|VerificarCooldown()|Verifica em OnTimer/OnTick se o cooldown<br>expirou e retoma operações (v3.29)|
|ContarOrdensDoEA()|Conta ordens pendentes deste EA no book —<br>usado para verificação de integridade (v3.27)|
|AplicarEstoqueMaximo()|<br>Aplica o teto de Estoque Máximo via ordem a<br>mercado oposta de volume = k + v_próxima (k =<br>volume_atual - EstoqueMaximo). Em HEDGE,<br>fecha posições mais antigas com partial close|



© 2025 Trading Expert  |  Página 26 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Função**|**Descrição**|
|---|---|
||conforme necessário. (v3.29 revisada)|
|ObterVolumeTotalPosicoes()|Retorna o volume total das posições do EA<br>(HEDGE: soma por MagicNumber; NETTING:<br>volume da consolidada do símbolo). Usado por<br>AplicarEstoqueMaximo. (v3.29 revisada)|



### **9.3 Variáveis Globais de Estado** 

|**Variável**|**Tipo**|**Descrição**|
|---|---|---|
|robotAtivo|bool|EA está ativo ou não|
|metaAtingidaHoje|bool|Bloqueia reativação automática após<br>meta (v3.15)|
|ultimoResetLucroPrejuizo|datetime|Timestamp do último reset de lucro<br>(v3.21)|
|ultimaSincronizacao|datetime|Última vez que sincronização rodou<br>(v3.22)|
|emDesconexao|bool|EA estava desconectado do servidor<br>(v3.22)|
|timestampDesconexao|datetime|Momento exato da desconexão<br>(v3.23)|
|breakEvenAtivado|bool|Break Even já foi ativado (v3.22)|
|prejuizoDinamico|double|Piso atual de lucro garantido (v3.22)|
|nivelBaseTrailing|double|Lucro base para cálculo do Trailing<br>Loss (v3.22)|
|isHedge|bool|Tipo de conta: true=HEDGE,<br>false=NETTING (v3.21)|
|emCooldown|bool|EA está em pausa após stop loss<br>(v3.29)|
|inicioCooldown|datetime|Momento do início do cooldown atual<br>(v3.29)|
|tentativaAtual|int|Contador de stop losses consecutivos<br>no dia (v3.29)|
|tempoCooldownSegundos|int|Duração do cooldown corrente em<br>segundos (v3.29)|



### **9.4 Fluxo de Eventos** 

```
OnInit():
   → Detecta tipo de conta (HEDGE/NETTING)
   → Inicializa variáveis
```

```
   → Se StatusInicial=ATIVO: ativa e cria/carrega grade
```

```
OnTick():
```

```
   → Verifica horário de início (se InicioAutomatico)
```

```
   → Verifica horário de fechamento
```

```
   → Verifica meta de lucro/prejuízo
```

© 2025 Trading Expert  |  Página 27 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

```
   → Atualiza painel L/P
```

```
OnTradeTransaction() [deal executado]:
   → Identifica deal por MagicNumber + Symbol
   → Verifica se parcial ou completa
   → Atualiza array
   → Salva CSV
   → InserirOrdensExtremas()
```

```
OnTimer() [1s]:
   → Detecta reconexão → SincronizarComServidor()
   → Atualiza label L/P
OnDeinit():
   → Salva CSV
   → Cria backup CSV (v3.25)
```

© 2025 Trading Expert  |  Página 28 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

## **10. GLOSSÁRIO** 

### **10.1 Termos do EA** 

|**Termo**|**Definição**|
|---|---|
|Grade Parcial|Estratégia de manter apenas 2 ordens no MT5 enquanto o<br>restante está em memória|
|Ordem Extrema|A ordem mais distante do preço atual em cada lado (BUY<br>maior / SELL menor)|
|Gain|Ordem oposta criada após execução, calculada a GainPips<br>do preço original|
|Consolidação|Soma dos volumes de ordens do mesmo tipo/preço no<br>mesmo slot do array|
|Tick Size|Menor variação válida de preço para um ativo (ex: WIN = 5<br>pts, EURUSD = 0.00001)|
|Break Even|Ponto a partir do qual o piso de perda é zerado — lucro<br>garantido em zero|
|Trailing Loss|Stop móvel de lucro: à medida que o lucro sobe, o piso<br>sobe junto|
|Sincronização|Processo de reconciliar o array interno com deals<br>executados no servidor|
|MagicNumber|Número identificador único que separa as ordens deste EA<br>de outros|
|Piso Dinâmico|Valor mínimo de lucro garantido, atualizado pelo Trailing<br>Loss|
|Arredondamento Tick|Ajuste automático do preço para múltiplo do tick size<br>(v3.26)|
|CSV Backup|Cópia do arquivo de grade criada com timestamp ao<br>desativar o EA (v3.25)|
|Estoque Máximo|Limite máximo de VOLUME REAL do ativo (ações,<br>contratos), na mesma unidade dos volumes das ordens da<br>grade. Ao ser excedido, o EA dispara ordem a mercado<br>oposta para retornar ao limite (v3.28 / v3.29)|
|Proteção a Mercado|<br>Ordem a mercado oposta enviada quando volume_atual ><br>EstoqueMaximo, com volume = k + v_próxima onde k =<br>volume_atual - EstoqueMaximo (na mesma unidade dos<br>volumes das ordens da grade). Substitui a antiga Stop de<br>Proteção pendente da v3.28. (v3.29 revisada)|
|Cooldown|<br>Pausa temporária após stop loss antes de retomar<br>operações; bloqueia sincronização e processamento de<br>deals (v3.29)|
|Backoff Exponencial|<br>Estratégia em que o tempo de pausa dobra a cada nova<br>tentativa (30→60→120 minutos) (v3.29)|



### **10.2 Siglas** 

© 2025 Trading Expert  |  Página 29 de 30 

Gradient Grid EA v3.26  |  Documentação do Usuário 

|**Sigla**|**Significado**|
|---|---|
|EA|Expert Advisor — robô de trading no MT5|
|MT5|MetaTrader 5 — plataforma de negociação|
|BID|Melhor preço de compra no book de ofertas|
|ASK|Melhor preço de venda no book de ofertas|
|CSV|Comma-Separated Values — formato de arquivo de texto tabular|
|HEDGE|Tipo de conta que permite múltiplas posições opostas|
|NETTING|Tipo de conta que consolida posições opostas em uma só|
|J|Multiplicador de volume progressivo|
|K|Multiplicador de distância progressiva|
|B3|Brasil, Bolsa, Balcão — bolsa de valores brasileira|
|WIN|Mini-contrato de Índice Bovespa negociado na B3|
|WDO|Mini-contrato de Dólar negociado na B3|



#### **🎉  FIM DA DOCUMENTAÇÃO  🎉** 

Gradient Grid EA v3.29  |  © 2025-2026 Trading Expert 

© 2025 Trading Expert  |  Página 30 de 30 


# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **MetaTrader 5 Expert Advisor (EA)** written in MQL5, implementing a **Linear Gradient** grid trading strategy. The EA places a grid of pending orders (BUY STOP above and SELL STOP below the current price) with configurable spacing, volume, and risk management rules.

The repository contains two files representing successive versions of the same EA:
- `Gradiente_Linear_3_28.mq5` — stable baseline (v3.28)
- `Gradiente_Linear_3_29.mq5` — current version with cooldown backoff after stop loss (v3.29)

## Development Environment

MQL5 files are compiled and run inside **MetaTrader 5**. There is no standalone build tool or test runner outside of MT5. To compile:

1. Open MetaTrader 5.
2. Open the MetaEditor (F4).
3. Open the `.mq5` file and press **F7** (or Compile button) to build the `.ex5` binary.
4. Errors and warnings appear in the MetaEditor Errors tab.

There are no automated tests, linters, or CI pipelines in this repository.

## Architecture

### Core Data Structure

The entire grid state lives in a single global array:

```mql5
OriginalOrderInfo originalOrders[];  // line ~205
```

Each element tracks a pending order's `ticket`, `originalPrice`, `volume`, `orderType`, and `comment`. Orders are **identified by ticket** (not price) to handle partial fills and reconnections correctly.

### Grid Lifecycle

1. **`CriarGradeInicialCompleta()`** (line ~542) — calculates all BUY STOP and SELL STOP price levels using the K (distance multiplier) and J (volume multiplier) progressions, populates `originalOrders[]`, then sends them to MT5.
2. **`OnTradeTransaction()`** (line ~2827) — the main event loop. When a pending order fills, it:
   - Locates the filled order in `originalOrders[]` by ticket.
   - Calculates the opposite-side counter-order using `originalPrice` (never the fill price).
   - Places the counter-order immediately.
3. **`SincronizarComServidor()`** (line ~1829) — called from `OnTimer()` after reconnection; rebuilds `originalOrders[]` from `HistoryDeals` to recover state without relying on in-memory data.

### State Persistence

Grid state is saved to a CSV file (`<Symbol>_<MagicNumber>_Grade.csv`) in the MT5 common folder at critical moments: `OnDeinit`, grid creation, meta actions, and manual button clicks. On activation without recreating (`OnClickBtnAtivarSemCriar`), the EA loads the CSV to map existing book orders back into `originalOrders[]`.

### Risk Management Layers (in priority order)

| Feature | Parameter(s) | Logic location |
|---|---|---|
| Profit target / max loss | `LucroAlvo`, `PrejuizoMaximo` | `VerificarMetaLucroPrejuizo()` ~1541 |
| Break Even | `BreakEvenValor` | inside `VerificarMetaLucroPrejuizo()` |
| Trailing Loss | `TrailingLossValor` | inside `VerificarMetaLucroPrejuizo()` |
| Max stock (position limit) | `EstoqueMaximo` | order placed mid-point in `OnTradeTransaction()` |
| Cooldown after stop loss | `AcaoAposStopLoss = ACAO_STOP_COOLDOWN` | `VerificarCooldown()` ~1489 |

### HEDGE vs NETTING

`isHedge` is detected at `OnInit()`. P&L calculations filter by `MagicNumber` on HEDGE accounts; on NETTING accounts the EA reads the consolidated position for the symbol.

### Panel / UI

`CriarPainel()` (~2142) draws a chart panel with buttons: **Iniciar** (create new grid), **Ativar sem Criar** (load CSV and map existing orders), **Cancelar Ordens**, and **Cancelar Tudo**. `OnChartEvent()` dispatches button clicks to their respective handlers (`OnClickBtn*`).

## Key Conventions

- **Prices are always rounded to tick size** via `ArredondarPreco()` before storage or order submission (introduced in v3.26 to fix rounding issues with K/J progressions).
- **Counter-orders use `originalPrice`**, not the execution price, to maintain the intended grid geometry even after slippage.
- **Order consolidation**: if two grid calculations produce the same type + exact price, their volumes are summed into one order rather than sending duplicates.
- `ModoBrasileiro = true` treats every digit as one pip (B3 futures); `false` uses the standard 5-digit forex convention.
- `MagicNumber` isolates this EA's orders from manual trades and other EAs on the same chart.

## Versioning Pattern

Each version increment is documented at the top of the `.mq5` file as a changelog comment. New versions are saved as a **new file** (e.g., `_3_29.mq5`), not by overwriting the previous version, preserving a working fallback.

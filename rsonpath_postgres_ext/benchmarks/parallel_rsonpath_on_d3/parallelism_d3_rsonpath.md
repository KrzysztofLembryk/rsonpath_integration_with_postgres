# Wielowątkowość rsonpath na D3 -- 2026-04-28

## Konfiguracja
- PostgreSQL 13.23 release build
- Rozszerzenie skompilowane z `--release`
- Dane: D3, 5 944 139 wierszy, ~11 GB (TOAST EXTENDED)
- Zapytanie: `SELECT sum(rsonpath_ext_count('$.title', data::text)) FROM d3_papers`
- CPU: Intel i7-8565U na moim laptopie -- 4 rdzenie fizyczne, 8 wątków
  logicznych (hyperthreading)

## Zmiana w kodzie

Domyślnie pgrx oznacza wszystkie funkcje jako `PARALLEL UNSAFE`,
co blokuje równoległe plany w PostgreSQL.
Dodałem atrybuty `immutable` i `parallel_safe` do wszystkich `#[pg_extern]`:

```rust
#[pg_extern(immutable, parallel_safe)]
fn rsonpath_ext_count(...) -> i64 { ... }
```

## Weryfikacja

```sql
SELECT proname, proparallel FROM pg_proc WHERE proname LIKE 'rsonpath_%';
-- proparallel = 's' (safe)
```

W planie zapytania pojawia się:
```
Gather (Workers Planned: N, Workers Launched: N)
  Parallel Aggregate
    Parallel Seq Scan on d3_papers
```

## Wyniki (3 powtórzenia każdej konfiguracji, średnia)

| max_parallel_workers_per_gather | Faktyczna liczba workerów | Średni czas | Przyspieszenie |
|--------------------------------:|--------------------------:|------------:|---------------:|
|                               0 |              0 (sekwencyjnie) |   107.9 s   |          1.00x |
|                               2 |                         2 |    70.4 s   |          1.53x |
|                               3 |                         3 |    71.9 s   |          1.50x |
|                               8 |          7 (cap globalny) |    55.7 s   |          1.94x |

Pojedyncze pomiary:
- 0 workerów: 107.9, 107.5, 108.4 s
- 2 workery: 70.1, 70.1, 70.8 s
- 3 workery: 70.8, 70.8, 74.0 s
- 7 workerów: 55.0, 56.5, 55.6 s

## Analiza

Maksymalne przyspieszenie ~2x mimo 7 workerów wynika z trzech rzeczy:
1. Hyperthreading na i7-8565U typowo daje 20-30% dodatkowej przepustowości,
   nie 100%. Realny limit dla mojego laptopa to ~4-5x, nie 8x.
2. Workload jest częściowo I/O-bound -- wcześniejszy profil perf pokazał
   ~33% czasu na `pglz_decompress` plus 7% memmove. Workerzy konkurują
   o ten sam dysk.
3. Współdzielony memory bandwidth -- nawet czysto CPU-owa praca dzieli
   przepustowość pamięci między workerów.

Skok 0 -> 2 dał 1.53x. 2 -> 3 nie dało nic -- 2 workery plus leader (3 procesy)
już wykorzystują dostępne pasmo, a trzeci worker dodaje tylko narzut koordynacji.
7 workerów plus leader = 8 procesów na 8 wątkach logicznych daje dodatkowe
~30% z hyperthreadingu, stąd 1.94x zamiast 1.50x.

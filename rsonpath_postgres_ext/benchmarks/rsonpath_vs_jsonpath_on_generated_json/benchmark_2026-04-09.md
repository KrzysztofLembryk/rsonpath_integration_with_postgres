# Wyniki benchmarku -- 2026-04-09

## Konfiguracja
- PostgreSQL 13.23 (pgrx 0.17.0)
- Dane: wygenerowany JSON, 67.17 MB (300 000 rekordow)
- Jeden wiersz w tabeli, caly JSON w jednej kolumnie (json + jsonb)
- 5 iteracji, 1 warmup
- rsonpath: dane z kolumny `json` (cast `::text`)
- jsonpath: dane z kolumny `jsonb` (bez konwersji -- najlepszy przypadek dla Postgresa)

## Wyniki

| Zapytanie                    | ext_count  | ext_str    | ext_json   | Postgres jsonpath | Przyspieszenie (count vs jsonpath) | Przyspieszenie (str vs jsonpath) |
|------------------------------|----------:|-----------:|-----------:|------------------:|-----------------------------------:|---------------------------------:|
| `$.records[*].name`          |  5 831 ms |   7 057 ms |   8 165 ms |       21 266 ms   |                             3.6x   |                            3.0x  |
| `$.records[*].scores[*]`    |  8 862 ms |  13 944 ms |  15 272 ms |      507 858 ms   |                            57.3x   |                           36.4x  |
| `$.records[*].address.city`  |  5 428 ms |   6 023 ms |   6 332 ms |       12 849 ms   |                             2.4x   |                            2.1x  |

## Porownanie wariantow rsonpath

| Zapytanie                    | ext_count  | ext_str    | ext_json   | Przyspieszenie (count vs json) |
|------------------------------|----------:|-----------:|-----------:|-------------------------------:|
| `$.records[*].name`          |  5 831 ms |   7 057 ms |   8 165 ms |                          1.4x  |
| `$.records[*].scores[*]`    |  8 862 ms |  13 944 ms |  15 272 ms |                          1.7x  |
| `$.records[*].address.city`  |  5 428 ms |   6 023 ms |   6 332 ms |                          1.2x  |

## Czas wstawienia danych
- Utworzenie tabeli: 21 ms
- INSERT (json + jsonb): 18 923 ms

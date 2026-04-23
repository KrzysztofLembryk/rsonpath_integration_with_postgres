# Profilowanie rsonpath na D3 -- 2026-04-23

## Konfiguracja
- PostgreSQL 13.23 release build (bez debug assertions)
- Rozszerzenie skompilowane z `--release`
- Dane: D3 (DBLP Discovery Dataset), 5 944 139 wierszy
- Tabela: `d3_papers` z kolumną `data json`, każdy wiersz to jeden artykuł
- Zapytanie profilowane: `rsonpath_ext_str('$.title', data::text)`
- Profilowanie: `perf record -g`

## Wyniki benchmarku

### Domyślne ustawienie TOAST (EXTENDED -- kompresja włączona, 11 GB na dysku)

| Zapytanie                    | rsonpath_ext_count | rsonpath_ext_str | Liczba dopasowań |
|------------------------------|-------------------:|-----------------:|-----------------:|
| `$.title`                    |        64 691 ms   |       87 058 ms  |        5 944 139 |
| `$.year`                     |        66 576 ms   |       84 961 ms  |        5 944 139 |
| `$.externalids.DOI`          |        68 046 ms   |       90 902 ms  |        5 944 139 |
| `$.authors[*].name`          |        75 250 ms   |      102 217 ms  |       18 784 025 |
| `$.s2fieldsofstudy[*].category` |     75 226 ms   |      101 537 ms  |       14 247 701 |

### EXTERNAL TOAST (bez kompresji, 28 GB na dysku)

| Zapytanie                    | rsonpath_ext_count | rsonpath_ext_str | porównanie do EXTENDED (count) |
|------------------------------|-------------------:|-----------------:|----------------------:|
| `$.title`                    |        95 068 ms   |      129 432 ms  |                 +47%  |
| `$.year`                     |        98 104 ms   |      126 096 ms  |                 +47%  |
| `$.externalids.DOI`          |       106 015 ms   |      132 074 ms  |                 +56%  |
| `$.authors[*].name`          |        61 131 ms   |      106 525 ms  |                 -19%  |
| `$.s2fieldsofstudy[*].category` |     74 411 ms   |       96 100 ms  |                  -1%  |

Uwaga: dla większości zapytań wersja BEZ kompresji była WOLNIEJSZA.
Postgres `pglz_decompress` jest na tyle tani, że zaoszczędzone CPU nie
rekompensuje zwiększonego I/O z rozrośniętej tabeli (11 GB --> 28 GB).
Domyślne ustawienie Postgres jest dobrze dostrojone dla tego workloadu.

## Profil perf -- EXTENDED (z kompresją)

| %     | Źródło                                    | Strona                                 |
|------:|-------------------------------------------|----------------------------------------|
| 32.8% | postgres `pglz_decompress`                | **Postgres** (dekompresja TOAST)       |
|  7.6% | libc `memmove`                            | Postgres (kopiowanie po dekompresji)   |
|  3.3% | rsonpath `run_on_subtree`                 | **Rsonpath** (silnik SIMD)             |
|  2.5% | rsonpath `TailSkip::skip`                 | **Rsonpath** (pomijanie)               |
|  2.2% | postgres `nocachegetattr`                 | Postgres (dostęp do krotek)            |
|  1.7% | rsonpath `automaton::minimize`            | **Rsonpath** (kompilacja zapytania)    |
|  1.4% | postgres `hash_search_with_hash_value`    | Postgres                               |
|  1.4% | postgres `AllocSetAlloc`                  | Postgres                               |

## Profil perf -- EXTERNAL (bez kompresji)

| %    | Źródło                                    | Strona                                 |
|-----:|-------------------------------------------|----------------------------------------|
| 3.6% | rsonpath `run_on_subtree`                 | **Rsonpath** (silnik SIMD)             |
| 3.3% | kernel `pread` (I/O)                      | OS (więcej bajtów z dysku)             |
| 3.2% | postgres `hash_search_with_hash_value`    | Postgres (więcej chunków TOAST do znalezienia) |
| 2.5% | rsonpath `TailSkip::skip`                 | **Rsonpath**                           |
| 2.3% | postgres `nocachegetattr`                 | Postgres (dostęp do krotek)            |
| 2.1% | libc `memmove`                            | libc                                   |
| 1.9% | rsonpath `automaton::minimize`            | **Rsonpath** (kompilacja zapytania)    |
| 1.8% | libc `malloc`                             | libc                                   |
| 1.7% | postgres `_bt_compare`                    | Postgres (btree TOAST lookup)          |
| 1.6% | postgres `AllocSetAlloc`                  | Postgres                               |
| 1.4% | postgres `LWLockAttemptLock`              | Postgres (locks)                       |
| 1.1% | rsonpath `BlockClassifier64Bit::classify` | **Rsonpath**                           |

Brak `pglz_decompress`. Na jego miejsce: kernel I/O, TOAST lookup (hash + btree),
memory. Profil jest płaski -- nic pojedynczego nie dominuje, ale sumarycznie
wolniejszy niż z kompresją.

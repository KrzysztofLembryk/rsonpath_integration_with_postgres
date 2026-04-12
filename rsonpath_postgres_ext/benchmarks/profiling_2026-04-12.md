# Profilowanie rsonpath -- 2026-04-12

## Konfiguracja
- PostgreSQL 13.23, release build (bez debug assertions i RANDOMIZE_ALLOCATED_MEMORY)
- Rozszerzenie skompilowane z `--release` (opt-level=3, lto=fat, codegen-units=1)
- Dane: wygenerowany JSON, ~180 MB w jednym wierszu tabeli (kolumna `json`)
- Zapytanie: `$.records[*].scores[*]` (przez rsonpath_ext_str)
- Profilowanie: `perf record -g`
- Uwaga: próba załadowania 900MB JSONa kończyła się crashem Postgresa (OOM przy konwersji na jsonb),
  a nawet 225MB przekraczało limit jsonb (256MB po parsowaniu). 180MB to największy rozmiar
  który działał stabilnie.

## Profil z debug Postgres (RANDOMIZE_ALLOCATED_MEMORY włączone)

| %     | Źródło                              | Opis                                             |
|------:|-------------------------------------|--------------------------------------------------|
| 34.8% | postgres `randomize_mem`            | Debugowy mechanizm -- zeruje każdą alokację      |
|  5.3% | postgres `pglz_decompress`          | Dekompresja TOAST                                |
|  4.5% | libc `memmove`                      | Kopiowanie pamięci                               |
|  4.5% | rsonpath `run_on_subtree`           | Główny silnik zapytań SIMD                       |
|  3.0% | postgres `AllocSetAlloc`            | Alokacja pamięci                                 |
|  2.1% | rsonpath `TailSkip::skip`           | Pomijanie nieistotnych fragmentów                |
|  2.0% | rsonpath `record_value_terminator`  | Zapis wyników dopasowania                        |
|  1.8% | pgrx `run_guarded`                  | Obsługa paniki w pgrx                            |
|  1.5% | pgrx `TableIterator::box_ret`       | Zwracanie wierszy do Postgresa                   |

Wniosek: 35% czasu to artefakt debugowy -- nie występuje w produkcji.

## Profil z release Postgres (bez debug assertions)

| %     | Źródło                                    | Opis                                       |
|------:|-------------------------------------------|--------------------------------------------|
| 25.5% | postgres `pglz_decompress`                | Dekompresja TOAST (rozpakowanie skompresowanego JSONa) |
| 14.0% | libc `memmove`                            | Kopiowanie pamięci (związane z dekompresją) |
|  8.2% | rsonpath `HeadSkip::run_head_skipping`    | SIMD pomijanie początkowe                  |
|  7.7% | rsonpath `Executor::run_on_subtree`       | Główny silnik zapytań SIMD                 |
|  3.8% | kernel                                    | Operacje na pamięci jądra                  |
|  2.3% | rsonpath `find_label_in_first_block`      | Dopasowywanie etykiet                      |
|  2.1% | libc `memcmp`                             | Porównywanie ciągów znaków                 |
|  2.0% | rsonpath `BlockClassifier256::classify`   | Klasyfikacja bloków SIMD                   |

## Podsumowanie

| Kategoria               | % czasu CPU |
|--------------------------|------------:|
| TOAST (dekompresja)      |       ~40%  |
| Silnik rsonpath          |       ~20%  |
| Operacje na pamięci      |       ~20%  |
| Kernel                   |        ~6%  |
| Reszta (pgrx, Postgres)  |       ~14%  |

## Wnioski

1. **Główny wąski punkt to dekompresja TOAST** -- Postgres kompresuje duże wartości (>2KB).
   Każde zapytanie płaci koszt dekompresji całego JSONa zanim rsonpath zaczyna pracę.

2. **Silnik rsonpath zajmuje tylko ~20% czasu CPU** -- jest szybki; overhead pochodzi z Postgresa,
   nie z rsonpath ani pgrx.

3. **Overhead pgrx jest pomijalny** -- `run_guarded` nie pojawia się nawet jako osobna pozycja
   w profilu release.

4. **Profil byłby inny dla małych JSONów** -- TOAST nie kompresuje wartości poniżej ~2KB.
   Przy wielu małych wierszach (np. dataset D3 z jednym JSONem na wiersz) silnik rsonpath
   stanowiłby większą część czasu. Kolejny MR z benchmarkiem na bardziej
   zróżnicowanych/płaskich danych pokaże ten profil.

5. **rsonpath obsługuje dane, których jsonb nie może** -- jsonb ma limit 256MB po parsowaniu;
   225MB surowego JSONa już przekracza ten limit. rsonpath działa na surowym tekście json
   bez tego ograniczenia.

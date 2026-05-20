-- RESULTS:
--           query_path           |          method          | match_count |   avg_ms   
-- -------------------------------+--------------------------+-------------+------------
--  $.authors[*]                  | jsonpath_gin_filter_only |     5907805 |  29912.751
--  $.authors[*]                  | jsonpath_no_cast         |    18784025 |  31017.942
--  $.authors[*]                  | rsonpath_ext_count       |    18784025 |  38463.632
--  $.authors[*]                  | jsonpath_no_cast_gin     |    18784025 |  43363.805
--  $.authors[*]                  | rsonpath_gin_filter_only |     5907805 | 122774.589
--  $.authors[*]                  | rsonpath_ext_count_gin   |    18784025 | 182492.981
--  $.authors[*].name             | jsonpath_gin_filter_only |     5907805 |  28578.241
--  $.authors[*].name             | jsonpath_no_cast         |    18784025 |  32042.751
--  $.authors[*].name             | rsonpath_ext_count       |    18784025 |  40757.772
--  $.authors[*].name             | jsonpath_no_cast_gin     |    18784025 |  44683.012
--  $.authors[*].name             | rsonpath_gin_filter_only |     5907805 | 123370.361
--  $.authors[*].name             | rsonpath_ext_count_gin   |    18784025 | 182256.538
--  $.externalids.DOI             | jsonpath_gin_filter_only |     5944139 |  28701.365
--  $.externalids.DOI             | jsonpath_no_cast         |     5944139 |  30297.759
--  $.externalids.DOI             | rsonpath_ext_count       |     5944139 |  39582.676
--  $.externalids.DOI             | jsonpath_no_cast_gin     |     5944139 |  42322.891
--  $.externalids.DOI             | rsonpath_gin_filter_only |     5944139 | 121153.205
--  $.externalids.DOI             | rsonpath_ext_count_gin   |     5944139 | 179755.093
--  $.s2fieldsofstudy[*].category | jsonpath_gin_filter_only |     5636615 |  29971.203
--  $.s2fieldsofstudy[*].category | jsonpath_no_cast         |    14247701 |  32686.583
--  $.s2fieldsofstudy[*].category | rsonpath_ext_count       |    14247701 |  41525.881
--  $.s2fieldsofstudy[*].category | jsonpath_no_cast_gin     |    14247701 |  43203.366
--  $.s2fieldsofstudy[*].category | rsonpath_gin_filter_only |     5636615 | 131670.548
--  $.s2fieldsofstudy[*].category | rsonpath_ext_count_gin   |    14247701 | 187935.905
--  $.title                       | jsonpath_gin_filter_only |     5944139 |  28962.579
--  $.title                       | jsonpath_no_cast         |     5944139 |  30971.067
--  $.title                       | rsonpath_ext_count       |     5944139 |  37639.887
--  $.title                       | jsonpath_no_cast_gin     |     5944139 |  41993.778
--  $.title                       | rsonpath_gin_filter_only |     5944139 | 124687.104
--  $.title                       | rsonpath_ext_count_gin   |     5944139 | 180043.974
--  $.year                        | jsonpath_no_cast         |     5944139 |  31055.175
--  $.year                        | jsonpath_gin_filter_only |     5944139 |  36552.025
--  $.year                        | rsonpath_ext_count       |     5944139 |  39061.697
--  $.year                        | jsonpath_no_cast_gin     |     5944139 |  50861.641
--  $.year                        | rsonpath_gin_filter_only |     5944139 | 123236.915
--  $.year                        | rsonpath_ext_count_gin   |     5944139 | 177597.530



\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

SELECT count(*) AS rows FROM d3_papers;

\echo 'Creating d3_papers_jsonb table...'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename  = 'd3_papers_jsonb') THEN
        EXECUTE 'CREATE TABLE d3_papers_jsonb AS SELECT id, data::jsonb AS data FROM d3_papers';
        RAISE NOTICE 'Table d3_papers_jsonb created.';
    ELSE
        RAISE NOTICE 'Table d3_papers_jsonb already exists. Skipping creation.';
    END IF;
END $$;

\echo 'Creating GIN indices (this might take a few minutes)...'
CREATE INDEX IF NOT EXISTS d3_papers_jsonb_rsonpath_gin_idx 
    ON d3_papers_jsonb USING gin (data rsonpath_jsonb_ops);

CREATE INDEX IF NOT EXISTS d3_papers_jsonb_jsonpath_gin_idx 
    ON d3_papers_jsonb USING gin (data jsonb_path_ops);

DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name text PRIMARY KEY,
    query_path text NOT NULL
);

INSERT INTO bench_queries(query_name, query_path) VALUES
    ('scalar_title',          '$.title'),
    ('scalar_year',           '$.year'),
    ('nested_obj_doi',        '$.externalids.DOI'),
    ('array_author_names',    '$.authors[*].name'),
    ('array_author_all',      '$.authors[*]'),
    ('array_fos_categories',  '$.s2fieldsofstudy[*].category');

DROP TABLE IF EXISTS bench_results;
CREATE TEMP TABLE bench_results (
    method      text NOT NULL,
    query_name  text NOT NULL,
    query_path  text NOT NULL,
    run_no      int  NOT NULL,
    elapsed_ms  numeric(20,3) NOT NULL,
    match_count bigint
);

-- Currently our GIN index only indexes KEYS not values, so we cannot do query like:
-- authorId == "123456789"
DO $$
DECLARE
    q    record;
    i    int;
    t0   timestamptz;
    ms   numeric(20,3);
    cnt  bigint;
    runs int := 1; 
BEGIN
    FOR q IN SELECT query_name, query_path FROM bench_queries ORDER BY query_name
    LOOP
        RAISE NOTICE 'Benchmarking: % (%)', q.query_name, q.query_path;

        -- WARMUP
        PERFORM sum(rsonpath_ext_count(q.query_path, p.data::text)) FROM d3_papers p;

        FOR i IN 1..runs LOOP
            
            ---------------------------------------------------------
            -- 1. BASELINES (Full Scans)
            ---------------------------------------------------------
            
            -- rsonpath count 
            t0 := clock_timestamp();

            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM d3_papers p;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('rsonpath_ext_count', q.query_name, q.query_path, i, ms, cnt);

            -- rsonpath str 
            -- t0 := clock_timestamp();

            -- SELECT count(*) INTO cnt
            -- FROM d3_papers p, LATERAL rsonpath_ext_str(q.query_path, p.data::text);

            -- ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            -- INSERT INTO bench_results VALUES ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt);

            -- -- rsonpath json
            -- t0 := clock_timestamp();

            -- SELECT count(*) INTO cnt
            -- FROM d3_papers p, LATERAL rsonpath_ext_json(q.query_path, p.data::text);

            -- ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            -- INSERT INTO bench_results VALUES ('rsonpath_ext_json', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath without cast
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM d3_papers_jsonb p,
                 LATERAL jsonb_path_query(p.data, q.query_path::jsonpath);

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('jsonpath', q.query_name, q.query_path, i, ms, cnt);


            ---------------------------------------------------------
            -- 2. GIN FILTER ONLY (Checks existence per document)
            ---------------------------------------------------------

            -- rsonpath boolean match (pure filtering overhead with GIN)
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM d3_papers_jsonb p WHERE p.data @@@ q.query_path;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('rsonpath_gin_filter_only', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath pure filter with GIN (@? operator)
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM d3_papers_jsonb p WHERE p.data @? q.query_path::jsonpath;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('jsonpath_gin_filter_only', q.query_name, q.query_path, i, ms, cnt);

            ---------------------------------------------------------
            -- 3. GIN ACCELERATED EXTRACTION
            ---------------------------------------------------------
            
            -- rsonpath count with GIN filter
            t0 := clock_timestamp();

            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM d3_papers_jsonb p WHERE p.data @@@ q.query_path;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('rsonpath_ext_count_gin', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath without cast with GIN filter
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM d3_papers_jsonb p,
                 LATERAL jsonb_path_query(p.data, q.query_path::jsonpath)
            WHERE p.data @? q.query_path::jsonpath;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('jsonpath_gin', q.query_name, q.query_path, i, ms, cnt);

        END LOOP;
    END LOOP;
END $$;

-- Summary Output
SELECT 
    query_path, 
    method, 
    match_count, 
    round(avg(elapsed_ms), 3) AS avg_ms
FROM bench_results
GROUP BY query_path, method, match_count
ORDER BY query_path, avg_ms;

-- round(min(elapsed_ms), 3) AS min_ms,
-- round(max(elapsed_ms), 3) AS max_ms
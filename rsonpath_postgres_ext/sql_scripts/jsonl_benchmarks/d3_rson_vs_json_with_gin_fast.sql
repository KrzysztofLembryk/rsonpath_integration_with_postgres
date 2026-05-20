-- We dont have value based filtering yet, only key based filtering, so here we have 
-- big jsonl with around 10% jsons having hobby key

\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

SELECT count(*) AS rows FROM data_1mb_jsons;

\echo 'Creating data_1mb_jsons_jsonb table...'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename  = 'data_1mb_jsons_jsonb') THEN
        EXECUTE 'CREATE TABLE data_1mb_jsons_jsonb AS SELECT data::jsonb AS data FROM data_1mb_jsons';
        RAISE NOTICE 'Table data_1mb_jsons_jsonb created.';
    ELSE
        RAISE NOTICE 'Table data_1mb_jsons_jsonb already exists. Skipping creation.';
    END IF;
END $$;

\echo 'Creating GIN indices (this might take a few minutes)...'
CREATE INDEX IF NOT EXISTS data_1mb_jsonb_rsonpath_gin_idx 
    ON data_1mb_jsons_jsonb USING gin (data rsonpath_jsonb_ops);

CREATE INDEX IF NOT EXISTS data_1mb_jsonb_jsonpath_gin_idx 
    ON data_1mb_jsons_jsonb USING gin (data jsonb_path_ops);

DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name text PRIMARY KEY,
    query_path text NOT NULL
);

-- Only ~10% of documents contain the "hobby" key
INSERT INTO bench_queries(query_name, query_path) VALUES
    ('rare_key_hobby', '$.hobby[*]');

DROP TABLE IF EXISTS bench_results;
CREATE TEMP TABLE bench_results (
    method      text NOT NULL,
    query_name  text NOT NULL,
    query_path  text NOT NULL,
    run_no      int  NOT NULL,
    elapsed_ms  numeric(20,3) NOT NULL,
    match_count bigint
);

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
        PERFORM sum(rsonpath_ext_count(q.query_path, p.data::text)) FROM data_1mb_jsons p;

        FOR i IN 1..runs LOOP
            
            ---------------------------------------------------------
            -- 1. BASELINES (Full Scans)
            ---------------------------------------------------------
            
            -- rsonpath count 
            t0 := clock_timestamp();

            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM data_1mb_jsons p;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('rsonpath_ext_count', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath without cast
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM data_1mb_jsons_jsonb p,
                 LATERAL jsonb_path_query(p.data, q.query_path::jsonpath);

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('jsonpath', q.query_name, q.query_path, i, ms, cnt);


            ---------------------------------------------------------
            -- 2. GIN FILTER ONLY (Checks existence per document)
            ---------------------------------------------------------
            
            -- rsonpath boolean match (pure filtering overhead with GIN)
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM data_1mb_jsons_jsonb p WHERE p.data @@@ q.query_path;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('rsonpath_gin_filter_only', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath pure filter with GIN (@? operator)
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM data_1mb_jsons_jsonb p WHERE p.data @? q.query_path::jsonpath;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('jsonpath_gin_filter_only', q.query_name, q.query_path, i, ms, cnt);

            ---------------------------------------------------------
            -- 3. GIN ACCELERATED EXTRACTION
            ---------------------------------------------------------
            
            -- rsonpath count with GIN filter
            t0 := clock_timestamp();

            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM data_1mb_jsons_jsonb p WHERE p.data @@@ q.query_path;

            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES ('rsonpath_ext_count_gin', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath without cast with GIN filter
            t0 := clock_timestamp();

            SELECT count(*) INTO cnt
            FROM data_1mb_jsons_jsonb p,
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
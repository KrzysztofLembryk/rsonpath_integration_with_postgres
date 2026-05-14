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

DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name text PRIMARY KEY,
    query_path text NOT NULL
);

-- Queries targeting the schema from generate_testdata.py
INSERT INTO bench_queries(query_name, query_path) VALUES
    ('scalar_email',            '$.email1'),
    ('scalar_address_city',     '$.address1.city1'),
    -- ('array_tags',              '$.tags1[*]'),
    -- ('array_cities',            '$.cities[*]'),
    ('nested_array_countries',  '$.nested1.nested2.countries[*]'),
    ('conditional_hobby',       '$.hobby[*]');

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
    runs int := 1; -- Number of iterations per query
BEGIN
    FOR q IN SELECT query_name, query_path FROM bench_queries ORDER BY query_name
    LOOP
        RAISE NOTICE 'Benchmarking: % (%)', q.query_name, q.query_path;

        -- WARMUP
        PERFORM sum(rsonpath_ext_count(q.query_path, p.data::text)) FROM data_1mb_jsons p;

        FOR i IN 1..runs LOOP
            -- 1. rsonpath (Count matches)
            t0 := clock_timestamp();
            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM data_1mb_jsons p;
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_count', q.query_name, q.query_path, i, ms, cnt);

            -- 2. rsonpath (Extract strings)
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM data_1mb_jsons p,
                 LATERAL rsonpath_ext_str(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt);

            -- 3. rsonpath (Extract JSON)
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM data_1mb_jsons p,
                 LATERAL rsonpath_ext_json(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_json', q.query_name, q.query_path, i, ms, cnt);

            -- 4. native Postgres jsonpath
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM data_1mb_jsons_jsonb p,
                 LATERAL jsonb_path_query(p.data, q.query_path::jsonpath);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('jsonpath', q.query_name, q.query_path, i, ms, cnt);
        END LOOP;
    END LOOP;
END $$;

-- Summary Output
SELECT 
    query_path, 
    method, 
    match_count, 
    round(avg(elapsed_ms), 3) AS avg_ms
    -- round(min(elapsed_ms), 3) AS min_ms,
    -- round(max(elapsed_ms), 3) AS max_ms
FROM bench_results
GROUP BY query_name, method, match_count
ORDER BY query_name, avg_ms;
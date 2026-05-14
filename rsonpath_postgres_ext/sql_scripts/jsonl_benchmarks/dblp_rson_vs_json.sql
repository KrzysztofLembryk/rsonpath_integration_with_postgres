-- On release:
--      query_name      |       method       | match_count |  avg_ms   |  min_ms   |  max_ms   
-- ----------------------+--------------------+-------------+-----------+-----------+-----------
--  array_author_names   | jsonpath           |    18784025 | 35042.522 | 35042.522 | 35042.522
--  array_author_names   | rsonpath_ext_count |    18784025 | 40516.415 | 40516.415 | 40516.415
--  array_author_names   | rsonpath_ext_str   |    18784025 | 49450.305 | 49450.305 | 49450.305
--  array_author_names   | rsonpath_ext_json  |    18784025 | 51760.182 | 51760.182 | 51760.182
--  array_fos_categories | jsonpath           |    14247701 | 31203.528 | 31203.528 | 31203.528
--  array_fos_categories | rsonpath_ext_count |    14247701 | 41948.420 | 41948.420 | 41948.420
--  array_fos_categories | rsonpath_ext_str   |    14247701 | 49283.692 | 49283.692 | 49283.692
--  array_fos_categories | rsonpath_ext_json  |    14247701 | 51804.230 | 51804.230 | 51804.230
--  nested_obj_doi       | jsonpath           |     5944139 | 29303.842 | 29303.842 | 29303.842
--  nested_obj_doi       | rsonpath_ext_count |     5944139 | 40832.494 | 40832.494 | 40832.494
--  nested_obj_doi       | rsonpath_ext_str   |     5944139 | 45273.103 | 45273.103 | 45273.103
--  nested_obj_doi       | rsonpath_ext_json  |     5944139 | 46114.566 | 46114.566 | 46114.566
--  scalar_title         | jsonpath           |     5944139 | 29062.295 | 29062.295 | 29062.295
--  scalar_title         | rsonpath_ext_count |     5944139 | 39318.640 | 39318.640 | 39318.640
--  scalar_title         | rsonpath_ext_str   |     5944139 | 44603.521 | 44603.521 | 44603.521
--  scalar_title         | rsonpath_ext_json  |     5944139 | 46042.591 | 46042.591 | 46042.591
--  scalar_year          | jsonpath           |     5944139 | 29047.450 | 29047.450 | 29047.450
--  scalar_year          | rsonpath_ext_count |     5944139 | 39636.226 | 39636.226 | 39636.226
--  scalar_year          | rsonpath_ext_str   |     5944139 | 44962.596 | 44962.596 | 44962.596
--  scalar_year          | rsonpath_ext_json  |     5944139 | 45752.006 | 45752.006 | 45752.006


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
        PERFORM sum(rsonpath_ext_count(q.query_path, p.data::text)) FROM d3_papers p;

        FOR i IN 1..runs LOOP
            -- 1. rsonpath (Count matches)
            t0 := clock_timestamp();
            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM d3_papers p;
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_count', q.query_name, q.query_path, i, ms, cnt);

            -- 2. rsonpath (Extract strings)
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM d3_papers p,
                 LATERAL rsonpath_ext_str(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt);

            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM d3_papers p,
                 LATERAL rsonpath_ext_json(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_json', q.query_name, q.query_path, i, ms, cnt);

            -- 3. native Postgres jsonpath (Count using jsonb_path_query on pre-parsed JSONB table)
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM d3_papers_jsonb p,
                 LATERAL jsonb_path_query(p.data, q.query_path::jsonpath);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('jsonpath', q.query_name, q.query_path, i, ms, cnt);
        END LOOP;
    END LOOP;
END $$;

-- Summary Output
SELECT 
    query_name, 
    method, 
    match_count, 
    round(avg(elapsed_ms), 3) AS avg_ms,
    round(min(elapsed_ms), 3) AS min_ms,
    round(max(elapsed_ms), 3) AS max_ms
FROM bench_results
GROUP BY query_name, method, match_count
ORDER BY query_name, avg_ms;
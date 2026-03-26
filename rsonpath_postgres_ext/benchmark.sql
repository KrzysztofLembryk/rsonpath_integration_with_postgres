-- benchmark_rsonpath_vs_postgres.sql
-- Run with: psql -d rsonpath_postgres_ext -f benchmark_rsonpath_vs_postgres.sql
-- Adjust path below to your generated large.json.

\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP TABLE IF EXISTS bench_json;
CREATE UNLOGGED TABLE bench_json (
    id   bigserial PRIMARY KEY,
    data json NOT NULL
);

COPY bench_json(data)
FROM '/tmp/large.json';

-- DROP TABLE IF EXISTS bench_jsonb;
-- CREATE UNLOGGED TABLE bench_jsonb AS
-- SELECT
--     id,
--     data::jsonb AS data
-- FROM bench_json;

-- 2) Precompute payload forms to reduce unrelated cast overhead during timing.
-- If you cast inside every timed query, you measure cast cost + query cost mixed together.
-- Precomputing once keeps benchmark focused on query execution itself.
-- DROP TABLE IF EXISTS bench_payload;
-- CREATE TEMP TABLE bench_payload AS
-- SELECT
--     data::text  AS txt,
--     data AS js,
--     data::jsonb AS jsb
-- FROM bench_json
-- LIMIT 1;

-- 3) Benchmark config/results tables.
DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name  text PRIMARY KEY,
    query_path  text NOT NULL,
    complexity  text NOT NULL
);

INSERT INTO bench_queries(query_name, query_path, complexity) VALUES
-- low: direct scalar per record
('q1_ids',            '$.records[*].id',            'low'),
-- medium: nested object field
('q2_cities',         '$.records[*].address.city',  'medium'),
-- high: nested array expansion (more matches)
('q3_scores_all',     '$.records[*].scores[*]',     'high');

DROP TABLE IF EXISTS bench_results;
CREATE TEMP TABLE bench_results (
    method      text NOT NULL,
    query_name  text NOT NULL,
    query_path  text NOT NULL,
    complexity  text NOT NULL,
    run_no      int  NOT NULL,
    elapsed_ms  numeric(20,3) NOT NULL,
    match_count bigint,
    ok          boolean NOT NULL DEFAULT true
);

-- 4) Benchmark loop.
DO $$
DECLARE
    q         record;
    i         int;
    t0        timestamptz;
    ms        numeric(20,3);
    cnt       bigint;
    runs      int := 1;
BEGIN
    FOR q IN
        SELECT query_name, query_path, complexity
        FROM bench_queries
        ORDER BY query_name
    LOOP
        -- Warmup per method (not recorded)
        PERFORM count(*)
        FROM bench_json p,
             LATERAL rsonpath_ext_table_iter_str(q.query_path, p.data::text);

        PERFORM count(*)
        FROM bench_json p,
             LATERAL rsonpath_ext_table_iter_json(q.query_path, p.data::text);

        -- PERFORM count(*)
        -- FROM bench_json p,
        --     LATERAL jsonb_path_query(p.data::jsonb, q.query_path::jsonpath) AS x(val);

        -- PERFORM count(*)
        -- FROM bench_jsonb p,
        --     LATERAL jsonb_path_query(p.data, q.query_path::jsonpath) AS x(val);

        FOR i IN 1..runs LOOP
            -- Method 1: extension string iterator
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_table_iter_str(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            INSERT INTO bench_results(method, query_name, query_path, complexity, run_no, elapsed_ms, match_count)
            VALUES ('rsonpath_ext_table_iter_str', q.query_name, q.query_path, q.complexity, i, ms, cnt);

            -- Method 2: extension json iterator
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_table_iter_json(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            INSERT INTO bench_results(method, query_name, query_path, complexity, run_no, elapsed_ms, match_count)
            VALUES ('rsonpath_ext_table_iter_json', q.query_name, q.query_path, q.complexity, i, ms, cnt);

            -- Method 3: native PostgreSQL JSONPath with jsonB cast
            -- t0 := clock_timestamp();
            -- SELECT count(*) INTO cnt
            -- FROM bench_json p,
            --     LATERAL jsonb_path_query(p.data::jsonb, q.query_path::jsonpath) AS x(val);
            -- ms := round(extract(epoch FROM (clock_timestamp() - t0)) * 1000.0, 3);

            -- INSERT INTO bench_results(method, query_name, query_path, complexity, run_no, elapsed_ms, match_count)
            -- VALUES ('postgres_jsonpath_with_cast_to_jsonb', q.query_name, q.query_path, q.complexity, i, ms, cnt);


            -- Method 4: native PostgreSQL JSONPath no cast
            -- t0 := clock_timestamp();
            -- SELECT count(*) INTO cnt
            -- FROM bench_jsonb p,
            --     LATERAL jsonb_path_query(p.data, q.query_path::jsonpath) AS x(val);
            -- ms := round(extract(epoch FROM (clock_timestamp() - t0)) * 1000.0, 3);

            -- INSERT INTO bench_results(method, query_name, query_path, complexity, run_no, elapsed_ms, match_count)
            -- VALUES ('postgres_jsonpath_no_cast', q.query_name, q.query_path, q.complexity, i, ms, cnt);
        END LOOP;
    END LOOP;
END $$;

-- 5) Per-run detailed output.
SELECT
    method,
    query_name,
    complexity,
    run_no,
    elapsed_ms,
    match_count
FROM bench_results
ORDER BY query_name, method, run_no;

-- 6) Aggregated summary.
SELECT
    query_name,
    complexity,
    method,
    min(match_count) AS match_count,
    round(avg(elapsed_ms), 3) AS avg_ms,
    round(min(elapsed_ms), 3) AS min_ms,
    round(max(elapsed_ms), 3) AS max_ms,
    round(stddev_samp(elapsed_ms), 3) AS stddev_ms
FROM bench_results
GROUP BY query_name, complexity, method
ORDER BY query_name, method;
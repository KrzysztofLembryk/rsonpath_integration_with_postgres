-- Time: 461896,559 ms (07:41,897) for 900MB
--         query              | method            | json_size_mb |  avg_ms   | ext_ms
-- ---------------------------+-------------------+--------------+-----------+-------
--  $.records[*].address.city | rsonpath_ext_json |     908      | 39698.881 | 31445 
--  $.records[*].address.city | rsonpath_ext_str  |     908      | 38024.570 | 31801 
--  $.records[*].name         | rsonpath_ext_json |     908      | 29122.311 | 21454 
--  $.records[*].name         | rsonpath_ext_str  |     908      | 27077.488 | 20901 
--  $.records[*].scores[*]    | rsonpath_ext_json |     908      | 50290.777 | 34251 
--  $.records[*].scores[*]    | rsonpath_ext_str  |     908      | 46977.955 | 34437 


-- Time: 119741,553 ms (01:59,742)
--            query           |      method       | json_size_mb |  avg_ms   | ext_ms
-- ---------------------------+-------------------+--------------+-------------------
--  $.records[*].address.city | rsonpath_ext_json |      224.669 | 10901.796 | 8727 
--  $.records[*].address.city | rsonpath_ext_str  |      224.669 | 10183.218 | 8055 
--  $.records[*].name         | rsonpath_ext_json |      224.669 |  7018.159 | 5286 
--  $.records[*].name         | rsonpath_ext_str  |      224.669 |  6880.815 | 5151
--  $.records[*].scores[*]    | rsonpath_ext_json |      224.669 | 12389.811 | 8464 
--  $.records[*].scores[*]    | rsonpath_ext_str  |      224.669 | 11997.557 | 8859 


-- Time: 45275,892 ms (00:45,276)
--         query              |      method       | json_size_mb |  avg_ms  
-- ---------------------------+-------------------+--------------+----------
--  $.records[*].address.city | rsonpath_ext_json |       89.674 | 3814.609
--  $.records[*].address.city | rsonpath_ext_str  |       89.674 | 3688.602
--  $.records[*].name         | rsonpath_ext_json |       89.674 | 2868.214
--  $.records[*].name         | rsonpath_ext_str  |       89.674 | 2693.928
--  $.records[*].scores[*]    | rsonpath_ext_json |       89.674 | 5032.800
--  $.records[*].scores[*]    | rsonpath_ext_str  |       89.674 | 4591.907

-- benchmark_rsonpath
-- Run with: psql -d rsonpath_postgres_ext -f benchmark_rsonpath.sql

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

DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name  text PRIMARY KEY,
    query_path  text NOT NULL
);

INSERT INTO bench_queries(query_name, query_path) VALUES
('q1_names',            '$.records[*].name'),
('q2_cities',         '$.records[*].address.city'),
('q3_scores_all',     '$.records[*].scores[*]');

DROP TABLE IF EXISTS bench_results;
CREATE TEMP TABLE bench_results (
    method      text NOT NULL,
    query_name  text NOT NULL,
    query_path  text NOT NULL,
    run_no      int  NOT NULL,
    elapsed_ms  numeric(20,3) NOT NULL,
    match_count bigint,
    json_size_mb numeric(20,3),
    ok          boolean NOT NULL DEFAULT true
);

DO $$
DECLARE
    q         record;
    i         int;
    t0        timestamptz;
    ms        numeric(20,3);
    cnt       bigint;
    js_size   numeric(20,3);
    runs      int := 1;
    ONE_MB numeric := 1024.0 * 1024.0;
BEGIN
    SELECT round((sum(octet_length(data::text)) / ONE_MB)::numeric, 3) INTO js_size FROM bench_json;

    FOR q IN
        SELECT query_name, query_path
        FROM bench_queries
        ORDER BY query_name
    LOOP
        RAISE NOTICE 'Running benchmark for query: % (%)', q.query_name, q.query_path;

        -- Warmup 
        PERFORM count(*)
        FROM bench_json p,
             LATERAL rsonpath_ext_str(q.query_path, p.data::text);

        PERFORM count(*)
        FROM bench_json p,
             LATERAL rsonpath_ext_json(q.query_path, p.data::text);

        FOR i IN 1..runs LOOP
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_str_timed(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            INSERT INTO bench_results(method, query_name, query_path, run_no, elapsed_ms, match_count, json_size_mb)
            VALUES ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt, js_size);

            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_json_timed(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            INSERT INTO bench_results(method, query_name, query_path, run_no, elapsed_ms, match_count, json_size_mb)
            VALUES ('rsonpath_ext_json', q.query_name, q.query_path, i, ms, cnt, js_size);
        END LOOP;
    END LOOP;
END $$;

-- 5) Per-run detailed output.
-- SELECT
--     method,
--     query_name,
--     run_no,
--     elapsed_ms,
--     match_count
-- FROM bench_results
-- ORDER BY query_name, method, run_no;

-- 6) Aggregated summary.
SELECT
    query_path AS query,
    method,
    min(json_size_mb) AS json_size_mb,
    -- min(match_count) AS match_count,
    round(avg(elapsed_ms), 3) AS avg_ms
    -- round(min(elapsed_ms), 3) AS min_ms,
    -- round(max(elapsed_ms), 3) AS max_ms
    -- round(stddev_samp(elapsed_ms), 3) AS stddev_ms
FROM bench_results
GROUP BY query, method
ORDER BY query, method;
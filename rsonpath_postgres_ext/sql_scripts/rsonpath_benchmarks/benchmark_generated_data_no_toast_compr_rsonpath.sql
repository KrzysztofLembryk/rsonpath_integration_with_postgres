-- benchmark_rsonpath no TOAST
-- SIZE: 908 MB
--            query           | method | avg_ms_no_TOAST   |  avg_ms  | diff_ms
-- ---------------------------+----------+--------------+-----------+-----------
--  $.records[*].address.city | r_json | 3849.416          | 4611.137 | +761.721
--  $.records[*].address.city | r_str  | 3634.400          | 4376.405 | +742.005
--  $.records[*].name         | r_json | 3564.332          | 4321.123 | +756.791
--  $.records[*].name         | r_str  | 3273.918          | 4013.329 | +739.411
--  $.records[*].scores[*]    | r_json | 7818.417          | 9513.402 | +1694.985
--  $.records[*].scores[*]    | r_str  | 7103.813          | 8979.106 | +1875.293

-- SIZE: 225 MB
--            query           | method | avg_ms_no_TOAST   | avg_ms   | diff_ms
-- ---------------------------+----------+--------------+- -----------------
--  $.records[*].address.city | r_json | 885.905           |  971.247 | +85.342
--  $.records[*].address.city | r_str  | 843.103           |  910.318 | +67.215
--  $.records[*].name         | r_json | 803.516           |  918.419 | +114.903
--  $.records[*].name         | r_str  | 756.246           |  862.711 | +106.465
--  $.records[*].scores[*]    | r_json | 1908.303          | 1893.580 | -14.723
--  $.records[*].scores[*]    | r_str  | 1681.221          | 1751.229 | +70.008

-- SIZE: 89.67 MB
--            query           | method | avg_ms_no_TOAST  | avg_ms  | diff_ms
-- ---------------------------+----------+--------------+------------------
--  $.records[*].address.city | r_json | 345.589          | 385.736 | +40.147
--  $.records[*].address.city | r_str  | 329.307          | 363.977 | +34.670
--  $.records[*].name         | r_json | 308.016          | 355.665 | +47.649
--  $.records[*].name         | r_str  | 300.837          | 337.032 | +36.195
--  $.records[*].scores[*]    | r_json | 706.078          | 757.570 | +51.492
--  $.records[*].scores[*]    | r_str  | 655.480          | 690.015 | +34.535

\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP TABLE IF EXISTS bench_json;
CREATE UNLOGGED TABLE bench_json (
    id   bigserial PRIMARY KEY,
    data json NOT NULL
);

-- Disable TOAST compression
ALTER TABLE bench_json ALTER COLUMN data SET STORAGE EXTERNAL;

COPY bench_json(data)
FROM '/tmp/large.json';

-- Precompute payload to reduce unrelated cast overhead during timing.
DROP TABLE IF EXISTS bench_payload;
CREATE TEMP TABLE bench_payload AS
SELECT
    data::text  AS txt,
    data AS js
FROM bench_json
LIMIT 1;

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
    runs      int := 2;
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
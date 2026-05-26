-- REMEMBER to run in !!! RELEASE !!!

-- avg Results for 5 runs
--            query           |       method       | json_size_mb |  avg_ms  
-- ---------------------------+--------------------+--------------+----------
--  $.records[*].address.city | rsonpath_ext_count |      908.275 | 2425.120
--  $.records[*].address.city | rsonpath_ext_json  |      908.275 | 3390.662
--  $.records[*].address.city | rsonpath_ext_str   |      908.275 | 3225.259
--  $.records[*].name         | rsonpath_ext_count |      908.275 | 2052.123
--  $.records[*].name         | rsonpath_ext_json  |      908.275 | 3075.771
--  $.records[*].name         | rsonpath_ext_str   |      908.275 | 2896.216
--  $.records[*].scores[*]    | rsonpath_ext_count |      908.275 | 2360.908
--  $.records[*].scores[*]    | rsonpath_ext_json  |      908.275 | 5893.704
--  $.records[*].scores[*]    | rsonpath_ext_str   |      908.275 | 5449.010

--            query           |       method       | json_size_mb | avg_ms  
-- ---------------------------+--------------------+--------------+---------
--  $.records[*].address.city | rsonpath_ext_count |       89.674 | 136.011
--  $.records[*].address.city | rsonpath_ext_json  |       89.674 | 225.883
--  $.records[*].address.city | rsonpath_ext_str   |       89.674 | 211.070
--  $.records[*].name         | rsonpath_ext_count |       89.674 | 101.302
--  $.records[*].name         | rsonpath_ext_json  |       89.674 | 200.556
--  $.records[*].name         | rsonpath_ext_str   |       89.674 | 182.776
--  $.records[*].scores[*]    | rsonpath_ext_count |       89.674 | 141.752
--  $.records[*].scores[*]    | rsonpath_ext_json  |       89.674 | 478.717
--  $.records[*].scores[*]    | rsonpath_ext_str   |       89.674 | 434.614

--           query           |       method       | json_size_mb | avg_ms  
-- ---------------------------+--------------------+--------------+---------
--  $.records[*].address.city | rsonpath_ext_count |       44.682 |  67.816
--  $.records[*].address.city | rsonpath_ext_json  |       44.682 | 113.181
--  $.records[*].address.city | rsonpath_ext_str   |       44.682 | 105.944
--  $.records[*].name         | rsonpath_ext_count |       44.682 |  50.510
--  $.records[*].name         | rsonpath_ext_json  |       44.682 |  99.796
--  $.records[*].name         | rsonpath_ext_str   |       44.682 |  90.945
--  $.records[*].scores[*]    | rsonpath_ext_count |       44.682 |  71.151
--  $.records[*].scores[*]    | rsonpath_ext_json  |       44.682 | 241.279
--  $.records[*].scores[*]    | rsonpath_ext_str   |       44.682 | 218.549

--            query           |       method       | json_size_mb | avg_ms 
-- ---------------------------+--------------------+--------------+--------
--  $.records[*].address.city | rsonpath_ext_count |       15.520 | 24.986
--  $.records[*].address.city | rsonpath_ext_json  |       15.520 | 41.022
--  $.records[*].address.city | rsonpath_ext_str   |       15.520 | 38.304
--  $.records[*].name         | rsonpath_ext_count |       15.520 | 18.561
--  $.records[*].name         | rsonpath_ext_json  |       15.520 | 35.349
--  $.records[*].name         | rsonpath_ext_str   |       15.520 | 32.369
--  $.records[*].scores[*]    | rsonpath_ext_count |       15.520 | 25.613
--  $.records[*].scores[*]    | rsonpath_ext_json  |       15.520 | 85.870
--  $.records[*].scores[*]    | rsonpath_ext_str   |       15.520 | 77.552

--            query           |       method       | json_size_mb | avg_ms 
-- ---------------------------+--------------------+--------------+--------
--  $.records[*].address.city | rsonpath_ext_count |        7.745 | 12.478
--  $.records[*].address.city | rsonpath_ext_json  |        7.745 | 18.877
--  $.records[*].address.city | rsonpath_ext_str   |        7.745 | 17.848
--  $.records[*].name         | rsonpath_ext_count |        7.745 |  9.324
--  $.records[*].name         | rsonpath_ext_json  |        7.745 | 15.555
--  $.records[*].name         | rsonpath_ext_str   |        7.745 | 14.209
--  $.records[*].scores[*]    | rsonpath_ext_count |        7.745 | 12.374
--  $.records[*].scores[*]    | rsonpath_ext_json  |        7.745 | 42.562
--  $.records[*].scores[*]    | rsonpath_ext_str   |        7.745 | 38.629

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

-- Precompute payload forms to reduce unrelated cast overhead during timing.
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
    runs      int := 5;
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
            -- string ext
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_str_timed(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            INSERT INTO bench_results(method, query_name, query_path, run_no, elapsed_ms, match_count, json_size_mb)
            VALUES ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt, js_size);

            -- json ext
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_json_timed(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            INSERT INTO bench_results(method, query_name, query_path, run_no, elapsed_ms, match_count, json_size_mb)
            VALUES ('rsonpath_ext_json', q.query_name, q.query_path, i, ms, cnt, js_size);

            -- count ext
            t0 := clock_timestamp();
            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM bench_json p;
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            INSERT INTO bench_results(method, query_name, query_path, run_no, elapsed_ms, match_count, json_size_mb)
            VALUES ('rsonpath_ext_count', q.query_name, q.query_path, i, ms, cnt, js_size);
        END LOOP;
    END LOOP;
END $$;


-- Aggregated summary.
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
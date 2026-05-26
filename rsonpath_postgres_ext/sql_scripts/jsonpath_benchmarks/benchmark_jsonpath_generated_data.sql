-- We benchmarks jsonpath in two scenarios: 
-- -> we need to cast to jsonb every time
-- -> everything is casted before

-- avg Results for 5 runs
--         query_path         | method  | match_count | json_size_mb | avg_time_ms 
-- ---------------------------+---------+-------------+--------------+-------------
--  $.records[*].address.city | no_cast |      400000 |       89.674 |    8700.085
--  $.records[*].name         | no_cast |      400000 |       89.674 |    8739.181
--  $.records[*].scores[*]    | no_cast |     1800148 |       89.674 |  356999.834

--        query_path         | method  | match_count | json_size_mb | avg_time_ms 
-- ---------------------------+---------+-------------+--------------+-------------
--  $.records[*].address.city | no_cast |      200000 |       44.682 |    1958.173
--  $.records[*].name         | no_cast |      200000 |       44.682 |    1936.865
--  $.records[*].scores[*]    | no_cast |      900333 |       44.682 |   72463.996

--         query_path         | method  | match_count | json_size_mb | avg_time_ms 
-- ---------------------------+---------+-------------+--------------+-------------
--  $.records[*].address.city | no_cast |       70000 |       15.520 |     244.926
--  $.records[*].name         | no_cast |       70000 |       15.520 |     240.332
--  $.records[*].scores[*]    | no_cast |      316110 |       15.520 |    4748.268

--         query_path         | method  | match_count | json_size_mb | avg_time_ms 
-- ---------------------------+---------+-------------+--------------+-------------
--  $.records[*].address.city | no_cast |       35000 |        7.745 |      60.347
--  $.records[*].name         | no_cast |       35000 |        7.745 |      59.727
--  $.records[*].scores[*]    | no_cast |      158160 |        7.745 |    1148.604


DROP TABLE IF EXISTS json_table;
DROP TABLE IF EXISTS benchmark_results;

CREATE TEMP TABLE json_table (
    id   SERIAL PRIMARY KEY,
    data json NOT NULL,
    data_jsonb jsonb
);

COPY json_table(data)
FROM '/tmp/large.json';

UPDATE json_table SET data_jsonb = data::jsonb;

CREATE TEMP TABLE benchmark_results (
    query_path text,
    method text,            -- 'measure_cast_only' | 'with_cast' | 'no_cast'
    match_count bigint,
    json_size_mb numeric(20,3),
    avg_time_ms numeric(20,3)
);

DO $$
DECLARE
    t0 timestamptz;
    elapsed numeric;
    total_time numeric;
    cnt bigint;
    q text;
    queries text[] := '{"$.records[*].name", "$.records[*].address.city", "$.records[*].scores[*]"}';
    num_runs integer := 5;
    js_size_mb numeric(20,3);
    ONE_MB numeric := 1024.0 * 1024.0;
BEGIN
    SELECT round((sum(octet_length(data::text)) / ONE_MB)::numeric, 3) INTO js_size_mb FROM json_table;

    -- total_time := 0;
    -- FOR i IN 1..num_runs LOOP
    --     t0 := clock_timestamp();
    --     SELECT count(jt.data::jsonb) INTO cnt FROM json_table jt WHERE jt.id = 1;
    --     elapsed := extract(epoch FROM (clock_timestamp() - t0)) * 1000.0;
    --     total_time := total_time + elapsed;
    -- END LOOP;
    -- INSERT INTO benchmark_results (query_path, method, match_count, json_size_mb, avg_time_ms)
    -- VALUES ('<CAST json TO jsonb time>', 'measure_cast_only', cnt, js_size_mb, round((total_time/num_runs)::numeric,3));

    -- For each jsonpath query: run with cast (data::jsonb) and without cast (data_jsonb)
    FOREACH q IN ARRAY queries LOOP
        -- on-the-fly cast
        -- total_time := 0;
        -- FOR i IN 1..num_runs LOOP
        --     t0 := clock_timestamp();
        --     SELECT count(*) INTO cnt
        --     FROM json_table jt,
        --          LATERAL jsonb_path_query(jt.data::jsonb, q::jsonpath);
        --     elapsed := extract(epoch FROM (clock_timestamp() - t0)) * 1000.0;
        --     total_time := total_time + elapsed;
        -- END LOOP;
        -- INSERT INTO benchmark_results (query_path, method, match_count, json_size_mb, avg_time_ms)
        -- VALUES (q, 'with_cast', cnt, js_size_mb, round((total_time/num_runs)::numeric,3));

        -- without cast
        total_time := 0;
        FOR i IN 1..num_runs LOOP
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM json_table jt,
                 LATERAL jsonb_path_query(jt.data_jsonb, q::jsonpath);
            elapsed := extract(epoch FROM (clock_timestamp() - t0)) * 1000.0;
            total_time := total_time + elapsed;
        END LOOP;
        INSERT INTO benchmark_results (query_path, method, match_count, json_size_mb, avg_time_ms)
        VALUES (q, 'no_cast', cnt, js_size_mb, round((total_time/num_runs)::numeric,3));
    END LOOP;
END $$;

SELECT * FROM benchmark_results ORDER BY query_path, method;
-- Benchmark jsonpath on jsonb  
-- --> with data generated via generate_testdata.py with SIZE_90_MB = 400_000
-- #################################################################################
-- Results:
--            query           | avg_time_ms |  count  | json_size_mb 
-- ---------------------------+-------------+---------+--------------
--  $.records[*].name         |   10561.397 |  400000 |       99.781
--  $.records[*].address.city |   10579.047 |  400000 |       99.781
--  $.records[*].scores[*]    |  381815.898 | 1800148 |       99.781


DROP TABLE IF EXISTS json_table;
DROP TABLE IF EXISTS benchmark_results;

CREATE TEMP TABLE json_table (
    id   SERIAL PRIMARY KEY,
    data jsonb NOT NULL
);

COPY json_table(data)
FROM '/tmp/large.json';

CREATE TEMP TABLE benchmark_results (
    query text,
    count INTEGER,
    json_size_mb numeric(20,3),
    avg_time_ms numeric(20,3)
);

DO $$
DECLARE
    t0  timestamptz;
    elapsed numeric;
    total_time numeric;
    cnt bigint;
    q text;
    queries text[] := '{"$.records[*].name", "$.records[*].address.city", "$.records[*].scores[*]"}';
    num_runs integer := 1;
    js_size_mb numeric(20,3);
    ONE_MB numeric := 1024.0 * 1024.0;
BEGIN

    SELECT round((sum(octet_length(data::text)) / ONE_MB)::numeric, 3) INTO js_size_mb FROM json_table;

    FOREACH q IN ARRAY queries LOOP
        total_time := 0;
        
        FOR i IN 1..num_runs LOOP
            t0 := clock_timestamp();
            
            SELECT count(*) INTO cnt
            FROM json_table jt,
                 LATERAL jsonb_path_query(jt.data, q::jsonpath)
            WHERE jt.id = 1;
            
            elapsed := extract(epoch FROM (clock_timestamp() - t0)) * 1000.0;
            total_time := total_time + elapsed;
        END LOOP;
        
        INSERT INTO benchmark_results (query, count, json_size_mb, avg_time_ms)
        VALUES (q, round((total_time / num_runs)::numeric, 3), cnt, js_size_mb);
        
    END LOOP;

END $$;

SELECT * FROM benchmark_results;
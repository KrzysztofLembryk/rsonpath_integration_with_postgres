-- Benchmark jsonpath on json with cast to jsonb 
-- --> data generated via generate_testdata.py with SIZE_90_MB = 400_000
-- Greater sizes DO NOT WORK WITH JSONB
-- #################################################################################
-- Results:
--            query           | avg_time_ms |  count  
-- ===================================================
--  <CAST json TO jsonb time> |    1035.203 |       1
--  $.records[*].name         |    9365.056 |  400000
--  $.records[*].scores[*]    |  315178.160 | 1800148

DROP TABLE IF EXISTS json_table;
DROP TABLE IF EXISTS benchmark_results;

CREATE TEMP TABLE json_table (
    id   SERIAL PRIMARY KEY,
    data json NOT NULL
);

COPY json_table(data)
FROM '/tmp/large.json';

CREATE TEMP TABLE benchmark_results (
    query text,
    avg_time_ms numeric(20,3),
    count INTEGER
);

DO $$
DECLARE
    t0  timestamptz;
    elapsed numeric;
    total_time numeric;
    cnt bigint;
    q text;
    queries text[] := '{"$.records[*].name", "$.records[*].scores[*]"}';
    num_runs integer := 3;
BEGIN

    -- Benchmarking just the json to jsonb casting time
    total_time := 0;
    FOR i IN 1..num_runs LOOP
        t0 := clock_timestamp();
        
        SELECT count(jt.data::jsonb) INTO cnt
        FROM json_table jt
        WHERE jt.id = 1;
        
        elapsed := extract(epoch FROM (clock_timestamp() - t0)) * 1000.0;
        total_time := total_time + elapsed;
    END LOOP;
    
    INSERT INTO benchmark_results (query, avg_time_ms, count)
    VALUES ('<CAST json TO jsonb time>', round((total_time / num_runs)::numeric, 3), cnt);


    FOREACH q IN ARRAY queries LOOP
        total_time := 0;
        
        FOR i IN 1..num_runs LOOP
            t0 := clock_timestamp();
            
            SELECT count(*) INTO cnt
            FROM json_table jt,
                 LATERAL jsonb_path_query(jt.data::jsonb, q::jsonpath)
            WHERE jt.id = 1;
            
            elapsed := extract(epoch FROM (clock_timestamp() - t0)) * 1000.0;
            total_time := total_time + elapsed;
        END LOOP;
        
        INSERT INTO benchmark_results (query, avg_time_ms, count)
        VALUES (q, round((total_time / num_runs)::numeric, 3), cnt);
        
    END LOOP;

END $$;

SELECT * FROM benchmark_results;
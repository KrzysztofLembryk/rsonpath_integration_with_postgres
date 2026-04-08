-- Benchmark jsonpath on jsonb  
-- --> with data generated via generate_testdata.py with SIZE_90_MB = 400_000
-- Greater sizes DO NOT WORK WITH JSONB
-- #################################################################################
-- Results:
--         query          | avg_time_ms |  count  
-- ===============================================
-- $.records[*].name      |    8745.669 |  400000
-- $.records[*].scores[*] |  316511.430 | 1800148

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
        
        INSERT INTO benchmark_results (query, avg_time_ms, count)
        VALUES (q, round((total_time / num_runs)::numeric, 3), cnt);
        
    END LOOP;

    -- For 90MB file
    -- query: $.records[*].name
    -- elapsed_native_json: 11757.487 ms

    -- query: $.records[*].scores[*]
    -- elapsed_native_json: 329637.032 ms 
END $$;

SELECT * FROM benchmark_results;
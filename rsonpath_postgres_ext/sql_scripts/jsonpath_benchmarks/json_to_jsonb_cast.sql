--            query           | avg_time_ms | json_size_mb 
-- ---------------------------+-------------+--------------
--  <CAST json TO jsonb time> |    1051.242 |       90.123
--  <CAST json TO jsonb time> |    2096.511 |      179.670

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
    json_size_mb numeric(20,3)
);

DO $$
DECLARE
    t0  timestamptz;
    elapsed numeric;
    total_time numeric;
    cnt bigint;
    js_size_mb numeric(20,3);
    num_runs integer := 5;
    ONE_MB numeric := 1024.0 * 1024.0;
BEGIN

    SELECT round((sum(octet_length(data::text)) / ONE_MB)::numeric, 3) INTO js_size_mb FROM json_table;

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
    
    INSERT INTO benchmark_results (query, avg_time_ms, json_size_mb)
    VALUES ('<CAST json TO jsonb time>', round((total_time / num_runs)::numeric, 3), js_size_mb);

END $$;

SELECT * FROM benchmark_results;
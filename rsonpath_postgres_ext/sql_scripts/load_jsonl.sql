\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP TABLE IF EXISTS bench_json;

-- CREATE UNLOGGED TABLE for fast bulk loading
CREATE UNLOGGED TABLE bench_json (
    id   bigserial PRIMARY KEY,
    data json NOT NULL
);

\echo 'Loading generated JSONL data...'

COPY bench_json(data) FROM PROGRAM
    'sed ''s/\\/\\\\/g'' /home/krzych/Studia/magisterka/proj_badawczy/rsonpath_postgres_ext/tests/testdata/large.jsonl'
    WITH (FORMAT text, DELIMITER E'\b');


\echo 'Data loaded successfully.'

-- Show the total row count and physical size footprint on the disk
SELECT count(*) AS total_rows,
       pg_size_pretty(pg_total_relation_size('bench_json')) AS total_table_size
FROM bench_json;

\echo '--- Starting Index Benchmark ---'

DO $$
DECLARE
    t0 timestamptz;
    time_without_index_ms numeric;
    time_with_index_ms numeric;
    cnt_no_index bigint;
    cnt_with_index bigint;
    speedup_percentage numeric;
    speedup_multiplier numeric;
BEGIN
    -- 1. Ensure no index exists initially
    DROP INDEX IF EXISTS idx_rsonpath_hobby;

    RAISE NOTICE 'Running query WITHOUT index...';
    t0 := clock_timestamp();
    
    SELECT count(*) INTO cnt_no_index 
    FROM bench_json 
    WHERE rsonpath_contains(data::text, '$.hobby[*]') = true;
    
    time_without_index_ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
    
    RAISE NOTICE '=> Time without index: % ms (Matches found: %)', time_without_index_ms, cnt_no_index;

    -- 3. Create index
    RAISE NOTICE 'Creating  index ';
    CREATE INDEX idx_rsonpath_hobby ON bench_json ( rsonpath_contains(data::text, '$.hobby[*]') );

    -- 4. Run with index
    RAISE NOTICE 'Running query WITH index...';
    t0 := clock_timestamp();
    
    SELECT count(*) INTO cnt_with_index 
    FROM bench_json 
    WHERE rsonpath_contains(data::text, '$.hobby[*]') = true;
    
    time_with_index_ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

    RAISE NOTICE '=> Time with index: % ms (Matches found: %)', time_with_index_ms, cnt_with_index;

    RAISE NOTICE '--------------------------------------------------';
    RAISE NOTICE 'BENCHMARK RESULTS ($.hobby[*])';
    RAISE NOTICE '--------------------------------------------------';
    
    IF time_with_index_ms > 0 THEN
        speedup_percentage := round(((time_without_index_ms - time_with_index_ms) / time_without_index_ms * 100.0)::numeric, 2);
        speedup_multiplier := round(time_without_index_ms / time_with_index_ms, 2);
        
        IF time_without_index_ms >= time_with_index_ms THEN
            RAISE NOTICE 'Status: INDEX IS FASTER';
            RAISE NOTICE 'Saved Time: % %% reduction in execution time', speedup_percentage;
            RAISE NOTICE 'Multiplier: %x faster', speedup_multiplier;
        ELSE
            RAISE NOTICE 'Status: INDEX IS SLOWER (Query lacks selectivity)';
            RAISE NOTICE 'Time Lost: % %% slower', abs(speedup_percentage);
        END IF;
    ELSE
        RAISE NOTICE 'Index was so fast it registered as 0 ms!';
    END IF;
    
    RAISE NOTICE '--------------------------------------------------';
END $$;
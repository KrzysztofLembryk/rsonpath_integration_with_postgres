\set ON_ERROR_STOP on
\timing on

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
        -- PERFORM count(*)
        -- FROM bench_json p,
        --      LATERAL rsonpath_ext_str(q.query_path, p.data::text);

        -- PERFORM count(*)
        -- FROM bench_json p,
        --      LATERAL rsonpath_ext_json(q.query_path, p.data::text);

        FOR i IN 1..runs LOOP
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_str_timed(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            -- INSERT INTO bench_results(method, query_name, query_path, run_no, elapsed_ms, match_count, json_size_mb)
            -- VALUES ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt, js_size);

            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM bench_json p,
                 LATERAL rsonpath_ext_json_timed(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

            -- INSERT INTO bench_results(method, query_name, query_path, run_no, elapsed_ms, match_count, json_size_mb)
            -- VALUES ('rsonpath_ext_json', q.query_name, q.query_path, i, ms, cnt, js_size);
        END LOOP;
    END LOOP;
END $$;
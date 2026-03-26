-- RESULTS:
-- ############### 225 MB #################
-- query: $.records[*].name | iters: 5 
    -- avg_str: 6570.401 ms 
    -- avg_json: 7183.342 ms
-- query: $.records[*].scores[*] | iters: 5 
    -- avg_str: 12106.319 ms 
    -- avg_json: 13251.050 ms 

-- ############### 90 MB #################
-- query: $.records[*].name | iters: 5 
    -- avg_str: 2734.915 ms 
    -- avg_json: 2961.138 ms
-- query: $.records[*].scores[*] | iters: 5 
    -- avg_str: 4953.588 ms 
    -- avg_json: 5396.439 ms 

DO $$
DECLARE
    t0        timestamptz;
    ms_str    numeric(20,3);
    ms_json   numeric(20,3);
    ms_str_total  numeric(20,3);
    ms_json_total numeric(20,3);
    cnt       bigint;
    ROW_ID    int := 2; -- 2 ~~ 90MB, 3 ~~ 225MB
    WARMUP    int := 1;
    ITERS     int := 5;
    i         int;
BEGIN
    -- ============================================================
    -- QUERY: $.records[*].name
    -- ============================================================
    -- Warmup
    FOR i IN 1..WARMUP LOOP
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_str('$.records[*].name', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_json('$.records[*].name', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
    END LOOP;

    ms_str_total  := 0;
    ms_json_total := 0;
    FOR i IN 1..ITERS LOOP
        t0 := clock_timestamp();
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_str('$.records[*].name', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
        ms_str_total := ms_str_total + round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

        t0 := clock_timestamp();
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_json('$.records[*].name', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
        ms_json_total := ms_json_total + round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
    END LOOP;

    RAISE NOTICE 'query: $.records[*].name | iters: % | avg_str: % ms | avg_json: % ms',
        ITERS,
        round(ms_str_total / ITERS, 3),
        round(ms_json_total / ITERS, 3);

    -- ============================================================
    -- QUERY: $.records[*].scores[*]
    -- ============================================================
    -- Warmup
    FOR i IN 1..WARMUP LOOP
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_str('$.records[*].scores[*]', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_json('$.records[*].scores[*]', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
    END LOOP;

    ms_str_total  := 0;
    ms_json_total := 0;
    FOR i IN 1..ITERS LOOP
        t0 := clock_timestamp();
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_str('$.records[*].scores[*]', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
        ms_str_total := ms_str_total + round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

        t0 := clock_timestamp();
        SELECT count(*) INTO cnt FROM json_table jt,
            LATERAL rsonpath_ext_table_iter_json('$.records[*].scores[*]', jt.data::text) AS r
        WHERE jt.id = ROW_ID;
        ms_json_total := ms_json_total + round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
    END LOOP;

    RAISE NOTICE 'query: $.records[*].scores[*] | iters: % | avg_str: % ms | avg_json: % ms',
        ITERS,
        round(ms_str_total / ITERS, 3),
        round(ms_json_total / ITERS, 3);
END $$;
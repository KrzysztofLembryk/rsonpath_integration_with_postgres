DO $$
DECLARE
    t0  timestamptz;
    ms_native numeric(20,3);
    cnt bigint;
BEGIN
    t0 := clock_timestamp();

    SELECT count(*) INTO cnt
    FROM json_table jt,
         LATERAL jsonb_path_query(jt.data::jsonb, '$.records[*].scores[*]'::jsonpath) AS r
    WHERE jt.id = 2;

    ms_native := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

    -- Print results
    RAISE NOTICE 'Rows matched: %, elapsed_native_json: % ms', cnt, ms_native;

    -- For 90MB file
    -- query: $.records[*].name
    -- elapsed_native_json: 11757.487 ms

    -- query: $.records[*].scores[*]
    -- elapsed_native_json: 329637.032 ms 
END $$;
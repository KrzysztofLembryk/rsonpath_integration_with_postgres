DO $$
DECLARE
    t0  timestamptz;
    ms_str  numeric(20,3);
    ms_json  numeric(20,3);
    ms_native numeric(20,3);
    cnt bigint;
    ROW_ID int := 3;  -- idx: 22 900MB json, idx 24: 200 MB json
BEGIN
     -- Json around 900MB (1GB is limit for one json row)
     -- 1. rsonpath str iterator
     t0 := clock_timestamp();

     EXPLAIN ANALYZE
     SELECT count(*) INTO cnt
     FROM json_table jt,
          LATERAL rsonpath_ext_table_iter_str('$.records[*].name', jt.data::text) AS r
     WHERE jt.id = ROW_ID;

     ms_str := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

     -- 2. rsonpath json iterator
     t0 := clock_timestamp();

     SELECT count(*) INTO cnt
     FROM json_table jt,
          LATERAL rsonpath_ext_table_iter_json('$.records[*].name', jt.data::text) AS r
     WHERE jt.id = ROW_ID;

     ms_json := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

     -- Print results
     -- RAISE NOTICE 'qeury: $.records[*].name, elapsed_str: % ms, elapsed_json: % ms', ms_str, ms_json;



     -- 1. rsonpath str iterator
     t0 := clock_timestamp();

     SELECT count(*) INTO cnt
     FROM json_table jt,
          LATERAL rsonpath_ext_table_iter_str('$.records[*].scores[*]', jt.data::text) AS r
     WHERE jt.id = ROW_ID;

     ms_str := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

     -- 2. rsonpath json iterator
     t0 := clock_timestamp();

     SELECT count(*) INTO cnt
     FROM json_table jt,
          LATERAL rsonpath_ext_table_iter_json('$.records[*].scores[*]', jt.data::text) AS r
     WHERE jt.id = ROW_ID;

     ms_json := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);

     -- Print results
     -- RAISE NOTICE 'qeury: $.records[*].scores[*], elapsed_str: % ms, elapsed_json: % ms', ms_str, ms_json;


     -- RESULTS for 900MB:
     -- qeury: $.records[*].name:
     -- elapsed_str: 29947.721 ms, 
     -- elapsed_json: 32267.341 ms

     -- query: $.records[*].scores[*]
     -- elapsed_str: 53756.785 ms
     -- elapsed_json: 59127.201 ms

     -- RESULTS for 200MB:
     -- qeury: $.records[*].name, 
     -- elapsed_str: 7466.729 ms, 
     -- elapsed_json: 8091.413 ms

     -- qeury: $.records[*].scores[*], 
     -- elapsed_str: 13391.216 ms, 
     -- elapsed_json: 14489.200 ms


     -- ################  RESULTS for 90MB ################
     -- qeury: $.records[*].name, 
     -- elapsed_str: 2623.748 ms, 
     -- elapsed_json: 2910.995 ms
     -- jsonpath: 11757.487 ms

     -- qeury: $.records[*].scores[*], 
     -- elapsed_str: 4894.945 ms, 
     -- elapsed_json: 5217.884 ms
     -- jsonpath: 329637.032 ms
END $$;
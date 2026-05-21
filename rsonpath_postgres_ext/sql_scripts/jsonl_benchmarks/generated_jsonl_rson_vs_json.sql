-- Results
--            query_path           |       method       | match_count |   avg_ms   
-- --------------------------------+--------------------+-------------+------------
--  $.address1.city1               | jsonpath_with_cast |       10000 |  12079.653
--  $.address1.city1               | jsonpath_no_cast   |       10000 |  12153.546
--  $.address1.city1               | rsonpath_ext_count |       10000 |  43522.942
--  $.address1.city1               | rsonpath_ext_str   |       10000 |  43632.577
--  $.address1.city1               | rsonpath_ext_json  |       10000 |  43664.766
--  $.cities[*]                    | rsonpath_ext_count |   300000000 |  45646.715
--  $.cities[*]                    | rsonpath_ext_str   |   300000000 |  84958.857
--  $.cities[*]                    | rsonpath_ext_json  |   300000000 |  97826.613
--  $.cities[*]                    | jsonpath_with_cast |   300000000 | 391020.057
--  $.cities[*]                    | jsonpath_no_cast   |   300000000 | 402916.620
--  $.email1                       | jsonpath_with_cast |       10000 |  12079.480
--  $.email1                       | jsonpath_no_cast   |       10000 |  12101.644
--  $.email1                       | rsonpath_ext_count |       10000 |  43475.215
--  $.email1                       | rsonpath_ext_str   |       10000 |  43637.784
--  $.email1                       | rsonpath_ext_json  |       10000 |  43699.923
--  $.hobby[*]                     | jsonpath_with_cast |        3734 |  12068.948
--  $.hobby[*]                     | jsonpath_no_cast   |        3734 |  12141.969
--  $.hobby[*]                     | rsonpath_ext_count |        3734 |  43563.827
--  $.hobby[*]                     | rsonpath_ext_json  |        3734 |  43637.019
--  $.hobby[*]                     | rsonpath_ext_str   |        3734 |  43714.196
--  $.nested1.nested2.countries[*] | rsonpath_ext_count |   300000000 |  45408.272
--  $.nested1.nested2.countries[*] | rsonpath_ext_str   |   300000000 |  87710.235
--  $.nested1.nested2.countries[*] | rsonpath_ext_json  |   300000000 | 101249.476
--  $.nested1.nested2.countries[*] | jsonpath_no_cast   |   300000000 | 390982.474
--  $.nested1.nested2.countries[*] | jsonpath_with_cast |   300000000 | 391686.303
--  $.tags1[*]                     | rsonpath_ext_count |   150000000 |  44424.402
--  $.tags1[*]                     | rsonpath_ext_str   |   150000000 |  64592.075
--  $.tags1[*]                     | rsonpath_ext_json  |   150000000 |  70752.957
--  $.tags1[*]                     | jsonpath_with_cast |   150000000 | 106523.196
--  $.tags1[*]                     | jsonpath_no_cast   |   150000000 | 106855.967


\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP INDEX IF EXISTS data_1mb_jsonb_rsonpath_gin_idx;
DROP INDEX IF EXISTS data_1mb_jsonb_jsonpath_gin_idx;

SELECT count(*) AS rows FROM data_1mb_jsons;

\echo 'Creating data_1mb_jsons_jsonb table...'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename  = 'data_1mb_jsons_jsonb') THEN
        EXECUTE 'CREATE TABLE data_1mb_jsons_jsonb AS SELECT data::jsonb AS data FROM data_1mb_jsons';
        RAISE NOTICE 'Table data_1mb_jsons_jsonb created.';
    ELSE
        RAISE NOTICE 'Table data_1mb_jsons_jsonb already exists. Skipping creation.';
    END IF;
END $$;

DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name text PRIMARY KEY,
    query_path text NOT NULL
);

INSERT INTO bench_queries(query_name, query_path) VALUES
    ('scalar_email',            '$.email1'),
    ('scalar_address_city',     '$.address1.city1'),
    ('array_tags',              '$.tags1[*]'),
    ('array_cities',            '$.cities[*]'),
    ('nested_array_countries',  '$.nested1.nested2.countries[*]'),
    ('conditional_hobby',       '$.hobby[*]');

DROP TABLE IF EXISTS bench_results;
CREATE TEMP TABLE bench_results (
    method      text NOT NULL,
    query_name  text NOT NULL,
    query_path  text NOT NULL,
    run_no      int  NOT NULL,
    elapsed_ms  numeric(20,3) NOT NULL,
    match_count bigint
);

DO $$
DECLARE
    q    record;
    i    int;
    t0   timestamptz;
    ms   numeric(20,3);
    cnt  bigint;
    runs int := 1;
BEGIN
    FOR q IN SELECT query_name, query_path FROM bench_queries ORDER BY query_name
    LOOP
        RAISE NOTICE 'Benchmarking: % (%)', q.query_name, q.query_path;

        -- WARMUP
        PERFORM sum(rsonpath_ext_count(q.query_path, p.data::text)) FROM data_1mb_jsons p;

        FOR i IN 1..runs LOOP
            -- rsonpath Count
            t0 := clock_timestamp();
            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM data_1mb_jsons p;
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_count', q.query_name, q.query_path, i, ms, cnt);

            -- rsonpath str 
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM data_1mb_jsons p,
                 LATERAL rsonpath_ext_str(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt);

            -- rsonpath json
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM data_1mb_jsons p,
                 LATERAL rsonpath_ext_json(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_json', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath with cast
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM data_1mb_jsons p,
                 LATERAL jsonb_path_query(p.data::jsonb, q.query_path::jsonpath);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('jsonpath_with_cast', q.query_name, q.query_path, i, ms, cnt);

            -- jsonpath without cast
            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM data_1mb_jsons_jsonb p,
                 LATERAL jsonb_path_query(p.data, q.query_path::jsonpath);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('jsonpath_no_cast', q.query_name, q.query_path, i, ms, cnt);
        END LOOP;
    END LOOP;
END $$;

-- Summary Output
SELECT 
    query_path, 
    method, 
    match_count, 
    round(avg(elapsed_ms), 3) AS avg_ms
FROM bench_results
GROUP BY query_path, method, match_count
ORDER BY query_path, avg_ms;
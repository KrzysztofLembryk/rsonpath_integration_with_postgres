-- Run with: psql -d rsonpath_postgres_ext -f benchmark_d3.sql
-- Prereq: load_d3.sql must have been run first

\set ON_ERROR_STOP on
\timing on

SELECT count(*) AS rows FROM d3_papers;

DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name text PRIMARY KEY,
    query_path text NOT NULL
);

INSERT INTO bench_queries(query_name, query_path) VALUES
    ('scalar_title',          '$.title'),
    ('scalar_year',           '$.year'),
    ('nested_obj_doi',        '$.externalids.DOI'),
    ('array_author_names',    '$.authors[*].name'),
    ('array_fos_categories',  '$.s2fieldsofstudy[*].category');

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

        PERFORM sum(rsonpath_ext_count(q.query_path, p.data::text))
        FROM d3_papers p;

        FOR i IN 1..runs LOOP
            t0 := clock_timestamp();
            SELECT sum(rsonpath_ext_count(q.query_path, p.data::text)) INTO cnt
            FROM d3_papers p;
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_count', q.query_name, q.query_path, i, ms, cnt);

            t0 := clock_timestamp();
            SELECT count(*) INTO cnt
            FROM d3_papers p,
                 LATERAL rsonpath_ext_str(q.query_path, p.data::text);
            ms := round((extract(epoch FROM (clock_timestamp() - t0)) * 1000.0)::numeric, 3);
            INSERT INTO bench_results VALUES
                ('rsonpath_ext_str', q.query_name, q.query_path, i, ms, cnt);
        END LOOP;
    END LOOP;
END $$;

SELECT query_name, method, match_count, round(avg(elapsed_ms), 3) AS avg_ms
FROM bench_results
GROUP BY query_name, method, match_count
ORDER BY query_name, method;

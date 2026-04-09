\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP TABLE IF EXISTS bench_json;
CREATE UNLOGGED TABLE bench_json (
    id   bigserial PRIMARY KEY,
    data json NOT NULL
);

COPY bench_json(data)
FROM '/tmp/large.json';


-- Queries:
-- '$.records[*].name'
-- '$.records[*].address.city'
-- '$.records[*].scores[*]'

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT count(*)
FROM bench_json p,
        LATERAL rsonpath_ext_str('$.records[*].scores[*]', p.data::text);

-- SELECT count(*) INTO cnt
-- FROM bench_json p,
--      LATERAL rsonpath_ext_json_timed(q.query_path, p.data::text);

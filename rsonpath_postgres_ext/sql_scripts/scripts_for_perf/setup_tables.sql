\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP TABLE IF EXISTS bench_json;
CREATE UNLOGGED TABLE bench_json (
    id   bigserial PRIMARY KEY,
    data json NOT NULL
);

-- Disable TOAST compression
ALTER TABLE bench_json ALTER COLUMN data SET STORAGE EXTERNAL;

COPY bench_json(data)
FROM '/tmp/large.json';

-- 2) Precompute payload forms to reduce unrelated cast overhead during timing.
-- If you cast inside every timed query, you measure cast cost + query cost mixed together.
-- Precomputing once keeps benchmark focused on query execution itself.
DROP TABLE IF EXISTS bench_payload;
CREATE TEMP TABLE bench_payload AS
SELECT
    data::text  AS txt,
    data AS js
FROM bench_json
LIMIT 1;

DROP TABLE IF EXISTS bench_queries;
CREATE TEMP TABLE bench_queries (
    query_name  text PRIMARY KEY,
    query_path  text NOT NULL
);

INSERT INTO bench_queries(query_name, query_path) VALUES
-- ('q1_names',            '$.records[*].name'),
-- ('q2_cities',         '$.records[*].address.city'),
('q3_scores_all',     '$.records[*].scores[*]');

DROP TABLE IF EXISTS bench_results;
CREATE TEMP TABLE bench_results (
    method      text NOT NULL,
    query_name  text NOT NULL,
    query_path  text NOT NULL,
    run_no      int  NOT NULL,
    elapsed_ms  numeric(20,3) NOT NULL,
    match_count bigint,
    json_size_mb numeric(20,3),
    ok          boolean NOT NULL DEFAULT true
);
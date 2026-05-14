-- Run with: psql -d rsonpath_postgres_ext -f load_d3.sql
-- Prereq: python3 tests/testdata/download_d3.py

\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP TABLE IF EXISTS d3_papers;
CREATE UNLOGGED TABLE d3_papers (
    id   bigserial PRIMARY KEY,
    data json NOT NULL
);

\echo 'Loading D3 data...'
COPY d3_papers(data) FROM PROGRAM
    'sed ''s/\\/\\\\/g'' /home/krzych/Studia/magisterka/proj_badawczy/rsonpath_postgres_ext/tests/testdata/d3/papers.jsonl'
    WITH (FORMAT text, DELIMITER E'\b');

SELECT count(*) AS row_count,
       pg_size_pretty(pg_total_relation_size('d3_papers')) AS table_size
FROM d3_papers;

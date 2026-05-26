\set ON_ERROR_STOP on
\timing on

CREATE EXTENSION IF NOT EXISTS rsonpath_postgres_ext;

DROP TABLE IF EXISTS d3_papers_b;
CREATE UNLOGGED TABLE d3_papers_b (
    id   bigserial PRIMARY KEY,
    data jsonb NOT NULL
);

COPY d3_papers_b(data) FROM PROGRAM
    'sed ''s/\\/\\\\/g'' /home/dominik/uw/projekt_badawczy/rsonpath_integration_with_postgres/rsonpath_postgres_ext/tests/testdata/d3/papers.jsonl'
    WITH (FORMAT text, DELIMITER E'\b');

SELECT count(*) AS row_count,
       pg_size_pretty(pg_total_relation_size('d3_papers_b')) AS table_size
FROM d3_papers_b;

CREATE INDEX d3_papers_b_rsonpath_idx ON d3_papers_b USING gin (data rsonpath_jsonb_ops);

SELECT pg_size_pretty(pg_relation_size('d3_papers_b_rsonpath_idx')) AS index_size;

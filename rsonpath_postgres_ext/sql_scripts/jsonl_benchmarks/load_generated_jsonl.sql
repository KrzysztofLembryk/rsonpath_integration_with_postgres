-- 1. Create a table to hold the JSONL data.
-- We use a single column of type JSONB for the best querying performance.
DROP TABLE IF EXISTS data_1mb_jsons;
CREATE TABLE data_1mb_jsons (
    data JSONB
);

COPY data_1mb_jsons(data) FROM PROGRAM
    'sed ''s/\\/\\\\/g'' /home/krzych/Studia/magisterka/proj_badawczy/rsonpath_postgres_ext/tests/testdata/large.jsonl'
    WITH (FORMAT text, DELIMITER E'\b');


-- Verify the load
SELECT count(*) FROM data_1mb_jsons;
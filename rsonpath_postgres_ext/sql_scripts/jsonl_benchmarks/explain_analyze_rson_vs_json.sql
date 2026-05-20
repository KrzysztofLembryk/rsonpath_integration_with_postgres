\echo "#################JSONPATH EXPLAIN ANALYZE##################"
EXPLAIN ANALYZE
SELECT count(*)
FROM data_1mb_jsons_jsonb p,
     LATERAL jsonb_path_query(p.data, '$.email1'::jsonpath);
    
\echo "#################RSONPATH EXPLAIN ANALYZE##################"
EXPLAIN ANALYZE
SELECT count(*)
FROM data_1mb_jsons p,
     LATERAL rsonpath_ext_json('$.email1', p.data::text);
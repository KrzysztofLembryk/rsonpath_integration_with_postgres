
SELECT count(*)
FROM bench_json p,
        LATERAL rsonpath_ext_str_timed('$.records[*].scores[*]', p.data::text);

SELECT count(*)
FROM bench_json p,
        LATERAL rsonpath_ext_json_timed('$.records[*].scores[*]', p.data::text);
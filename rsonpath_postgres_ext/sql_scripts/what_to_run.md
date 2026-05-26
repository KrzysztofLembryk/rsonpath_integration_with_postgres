# scripts to run
- benchmark_generated_data_rsonpath && benchmark_jsonpath_generated_data (900MB rsonpath, 
80MB r && j, 16MB r && j)
- d3_rson_vs_json (rson is much slower than jsonpath since jsons are small)
- generated_data_rson_vs_json_with_gin (rson should be much faster with GIN)
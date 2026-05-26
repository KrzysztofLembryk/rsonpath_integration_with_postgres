All results are averages over **5 runs**

# Rsonpath vs Jsonpath on single jsons

## Rsonpath 900MB json
```text
           query           |       method       | json_size_mb |  avg_ms  
---------------------------+--------------------+--------------+----------
 $.records[*].address.city | rsonpath_ext_count |      908.275 | 2425.120
 $.records[*].address.city | rsonpath_ext_json  |      908.275 | 3390.662
 $.records[*].address.city | rsonpath_ext_str   |      908.275 | 3225.259
 $.records[*].name         | rsonpath_ext_count |      908.275 | 2052.123
 $.records[*].name         | rsonpath_ext_json  |      908.275 | 3075.771
 $.records[*].name         | rsonpath_ext_str   |      908.275 | 2896.216
 $.records[*].scores[*]    | rsonpath_ext_count |      908.275 | 2360.908
 $.records[*].scores[*]    | rsonpath_ext_json  |      908.275 | 5893.704
 $.records[*].scores[*]    | rsonpath_ext_str   |      908.275 | 5449.010

```

## 90MB json
```text
        query_path         |    method          | json_size_mb | avg_time_ms 
---------------------------+--------------------+--------------+-------------
 $.records[*].address.city |    jsonpath        |       89.674 |    8700.085
 $.records[*].address.city | rsonpath_ext_count |       89.674 |    136.011
 $.records[*].address.city | rsonpath_ext_json  |       89.674 |    225.883
 $.records[*].address.city | rsonpath_ext_str   |       89.674 |    211.070

 $.records[*].name         |    jsonpath        |       89.674 |    8739.181
 $.records[*].name         | rsonpath_ext_count |       89.674 |    101.302
 $.records[*].name         | rsonpath_ext_json  |       89.674 |    200.556
 $.records[*].name         | rsonpath_ext_str   |       89.674 |    182.776

 $.records[*].scores[*]    |    jsonpath        |       89.674 |    356999.834
 $.records[*].scores[*]    | rsonpath_ext_count |       89.674 |    141.752
 $.records[*].scores[*]    | rsonpath_ext_json  |       89.674 |    478.717
 $.records[*].scores[*]    | rsonpath_ext_str   |       89.674 |    434.614
```

## 44MB json
```text
       query_path          |      method        | json_size_mb | avg_time_ms 
---------------------------+--------------------+--------------+-------------
 $.records[*].address.city |     jsonpath       |       44.682 |    1958.173
 $.records[*].address.city | rsonpath_ext_count |       44.682 |    67.816
 $.records[*].address.city | rsonpath_ext_json  |       44.682 |    113.181
 $.records[*].address.city | rsonpath_ext_str   |       44.682 |    105.944

 $.records[*].name         |     jsonpath       |       44.682 |    1936.865
 $.records[*].name         | rsonpath_ext_count |       44.682 |    50.510
 $.records[*].name         | rsonpath_ext_json  |       44.682 |    99.796
 $.records[*].name         | rsonpath_ext_str   |       44.682 |    90.945

 $.records[*].scores[*]    |     jsonpath       |       44.682 |    72463.996
 $.records[*].scores[*]    | rsonpath_ext_count |       44.682 |    71.151
 $.records[*].scores[*]    | rsonpath_ext_json  |       44.682 |    241.279
 $.records[*].scores[*]    | rsonpath_ext_str   |       44.682 |    218.549
```

## 16MB json
```text
        query_path         |      method        | json_size_mb | avg_time_ms 
---------------------------+-------------+--------------+-------------
 $.records[*].address.city |    jsonpath        |       15.520 |    244.926
 $.records[*].address.city | rsonpath_ext_count |       15.520 |    24.986
 $.records[*].address.city | rsonpath_ext_json  |       15.520 |    41.022
 $.records[*].address.city | rsonpath_ext_str   |       15.520 |    38.304

 $.records[*].name         |    jsonpath        |       15.520 |    240.332
 $.records[*].name         | rsonpath_ext_count |       15.520 |    18.561
 $.records[*].name         | rsonpath_ext_json  |       15.520 |    35.349
 $.records[*].name         | rsonpath_ext_str   |       15.520 |    32.369

 $.records[*].scores[*]    |    jsonpath        |       15.520 |    4748.268
 $.records[*].scores[*]    | rsonpath_ext_count |       15.520 |    25.613
 $.records[*].scores[*]    | rsonpath_ext_json  |       15.520 |    85.870
 $.records[*].scores[*]    | rsonpath_ext_str   |       15.520 |    77.552

```

## 8MB json
```text
        query_path         |      method        | json_size_mb | avg_time_ms 
---------------------------+-------------+--------------+-------------
 $.records[*].address.city |     jsonpath       |        7.745 |    60.347
 $.records[*].address.city | rsonpath_ext_count |        7.745 |    12.478
 $.records[*].address.city | rsonpath_ext_json  |        7.745 |    18.877
 $.records[*].address.city | rsonpath_ext_str   |        7.745 |    17.848

 $.records[*].name         |     jsonpath       |        7.745 |    59.727
 $.records[*].name         | rsonpath_ext_count |        7.745 |     9.324
 $.records[*].name         | rsonpath_ext_json  |        7.745 |    15.555
 $.records[*].name         | rsonpath_ext_str   |        7.745 |    14.209

 $.records[*].scores[*]    |     jsonpath       |        7.745 |    1148.604
 $.records[*].scores[*]    | rsonpath_ext_count |        7.745 |    12.374
 $.records[*].scores[*]    | rsonpath_ext_json  |        7.745 |    42.562
 $.records[*].scores[*]    | rsonpath_ext_str   |        7.745 |    38.629
```

# d3 Rsonpath vs Jsonpath
In d3 dataset each json (row in our table) is around **1.7 kB**,
```text
     query_name                |       method       | match_count |  avg_ms   
-------------------------------+--------------------+-------------+--------------
 $.authors[*]                  | jsonpath           |    18784025 | 32125.603
 $.authors[*]                  | rsonpath_ext_count |    18784025 | 37811.934
 $.authors[*]                  | rsonpath_ext_str   |    18784025 | 46521.180
 $.authors[*]                  | rsonpath_ext_json  |    18784025 | 50603.718
 $.s2fieldsofstudy[*].category | jsonpath           |    14247701 | 33984.821
 $.s2fieldsofstudy[*].category | rsonpath_ext_count |    14247701 | 40787.870
 $.s2fieldsofstudy[*].category | rsonpath_ext_str   |    14247701 | 47908.566
 $.s2fieldsofstudy[*].category | rsonpath_ext_json  |    14247701 | 48723.853
 $.title                       | jsonpath           |     5944139 | 32076.858
 $.title                       | rsonpath_ext_count |     5944139 | 37275.357
 $.title                       | rsonpath_ext_str   |     5944139 | 42781.894
 $.title                       | rsonpath_ext_json  |     5944139 | 43471.645
```


# with GIN: Rsonpath vs Jsonpath on generated data
Each row is around 1MB and after postgres compression around **395,987 kB**
```text
 query_path |          method          | match_count |  avg_ms   
------------+--------------------------+-------------+-----------
 $.hobby[*] | jsonpath                 |        3734 | 15441.249
 $.hobby[*] | rsonpath_ext_count       |        3734 | 48500.311

 $.hobby[*] | jsonpath_gin_filter_only |         932 | 12360.038
 $.hobby[*] | rsonpath_gin_filter_only |         932 |  8117.575
 $.hobby[*] | jsonpath_gin             |        3734 | 13436.985
 $.hobby[*] | rsonpath_ext_count_gin   |        3734 | 12349.180
```
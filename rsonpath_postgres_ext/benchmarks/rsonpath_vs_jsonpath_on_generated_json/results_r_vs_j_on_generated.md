# Rsonpath vs jsonpath on 90MB

```
        query              |      method       | json_size_mb |  avg_ms  
---------------------------+-------------------+--------------+----------
 $.records[*].name         | rsonpath_ext_json |       89.674 | 2868.214
 $.records[*].name         | rsonpath_ext_str  |       89.674 | 2693.928
 $.records[*].address.city | rsonpath_ext_json |       89.674 | 3814.609
 $.records[*].address.city | rsonpath_ext_str  |       89.674 | 3688.602
 $.records[*].scores[*]    | rsonpath_ext_json |       89.674 | 5032.800
 $.records[*].scores[*]    | rsonpath_ext_str  |       89.674 | 4591.907

## JSONB ##

           query           | json_size_mb | avg_time_ms 
---------------------------+--------------+-------------
 $.records[*].name         |       99.781 |   10561.397 
 $.records[*].address.city |       99.781 |   10579.047 
 $.records[*].scores[*]    |       99.781 |  381815.898 


## JSON with cast to JSONB ##

           query           | json_size_mb | avg_time_ms |
---------------------------+--------------+-------------+
 <CAST json TO jsonb time> |       89.674 |    1161.054 |
 $.records[*].name         |       89.674 |   10457.962 |
 $.records[*].address.city |       89.674 |   10268.039 |
 $.records[*].scores[*]    |       89.674 |  365784.442 |
```

# Rsonpath on 225MB and 900MB

```
Size 900MB

        query              | method            |  avg_ms   | ext_ms |  diff_ms
---------------------------+-------------------+-----------+--------+-----------
 $.records[*].address.city | rsonpath_ext_json | 39698.881 | 31445  |  8253.881
 $.records[*].address.city | rsonpath_ext_str  | 38024.570 | 31801  |  6223.570
 $.records[*].name         | rsonpath_ext_json | 29122.311 | 21454  |  7668.311
 $.records[*].name         | rsonpath_ext_str  | 27077.488 | 20901  |  6176.488
 $.records[*].scores[*]    | rsonpath_ext_json | 50290.777 | 34251  | 16039.777
 $.records[*].scores[*]    | rsonpath_ext_str  | 46977.955 | 34437  | 12540.955


Size 225MB
           query           |      method       |  avg_ms   | ext_ms |  diff_ms
---------------------------+-------------------+-----------+--------+----------
 $.records[*].address.city | rsonpath_ext_json | 10901.796 | 8727   | 2174.796
 $.records[*].address.city | rsonpath_ext_str  | 10183.218 | 8055   | 2128.218
 $.records[*].name         | rsonpath_ext_json |  7018.159 | 5286   | 1732.159
 $.records[*].name         | rsonpath_ext_str  |  6880.815 | 5151   | 1729.815
 $.records[*].scores[*]    | rsonpath_ext_json | 12389.811 | 8464   | 3925.811
 $.records[*].scores[*]    | rsonpath_ext_str  | 11997.557 | 8859   | 3138.557
```
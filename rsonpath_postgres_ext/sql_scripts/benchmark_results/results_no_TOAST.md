# Results TOAST vs no TOAST for rsonpath

```
SIZE: 908 MB
           query           | method | avg_ms_no_TOAST   |  avg_ms  | diff_ms
---------------------------+----------+--------------+-----------+-----------
 $.records[*].address.city | r_json | 3849.416          | 4611.137 | +761.721
 $.records[*].address.city | r_str  | 3634.400          | 4376.405 | +742.005
 $.records[*].name         | r_json | 3564.332          | 4321.123 | +756.791
 $.records[*].name         | r_str  | 3273.918          | 4013.329 | +739.411
 $.records[*].scores[*]    | r_json | 7818.417          | 9513.402 | +1694.985
 $.records[*].scores[*]    | r_str  | 7103.813          | 8979.106 | +1875.293

SIZE: 225 MB
           query           | method | avg_ms_no_TOAST   | avg_ms   | diff_ms
---------------------------+----------+--------------+- -----------------
 $.records[*].address.city | r_json | 885.905           |  971.247 | +85.342
 $.records[*].address.city | r_str  | 843.103           |  910.318 | +67.215
 $.records[*].name         | r_json | 803.516           |  918.419 | +114.903
 $.records[*].name         | r_str  | 756.246           |  862.711 | +106.465
 $.records[*].scores[*]    | r_json | 1908.303          | 1893.580 | -14.723
 $.records[*].scores[*]    | r_str  | 1681.221          | 1751.229 | +70.008

SIZE: 89.67 MB
           query           | method | avg_ms_no_TOAST  | avg_ms  | diff_ms
---------------------------+----------+--------------+------------------
 $.records[*].address.city | r_json | 345.589          | 385.736 | +40.147
 $.records[*].address.city | r_str  | 329.307          | 363.977 | +34.670
 $.records[*].name         | r_json | 308.016          | 355.665 | +47.649
 $.records[*].name         | r_str  | 300.837          | 337.032 | +36.195
 $.records[*].scores[*]    | r_json | 706.078          | 757.570 | +51.492
 $.records[*].scores[*]    | r_str  | 655.480          | 690.015 | +34.535
```
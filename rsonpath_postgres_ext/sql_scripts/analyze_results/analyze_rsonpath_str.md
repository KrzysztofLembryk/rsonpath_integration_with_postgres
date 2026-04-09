# 900MB - $.records[\*].name 

<pre>
                    QUERY PLAN                                                    
---------------------------------------------------------
 Aggregate  (cost=27022.01..27022.02 rows=1 width=8) (actual time=26182.072..26182.074 rows=1 loops=1)
   Output: count(*)
   Buffers: shared hit=3 read=39494 written=16076, temp read=16955 written=16955
   ->  Nested Loop  (cost=0.01..24022.01 rows=1200000 width=0) (actual time=25738.449..26097.126 rows=4000000 loops=1)
         Buffers: shared hit=3 read=39494 written=16076, temp read=16955 written=16955
         ->  Seq Scan on public.bench_json p  (cost=0.00..22.00 rows=1200 width=32) (actual time=0.005..0.009 rows=1 loops=1)
               Output: p.id, p.data
               Buffers: shared hit=1
         ->  Function Scan on public.<b><span style="color: red;">rsonpath_ext_str</span></b>  (cost=0.01..10.01 rows=1000 width=0) (actual <span style="color: red;">time=25738.441..25967.706</span> rows=4000000 loops=1)
               Output: rsonpath_ext_str.idx, rsonpath_ext_str.val
               Function Call: rsonpath_ext_str('$.records[*].name'::text, (p.data)::text)
               Buffers: shared hit=2 read=39494 written=16076, temp read=16955 written=16955
 Planning:
   Buffers: shared hit=2 read=1
 Planning Time: 0.082 ms
 Execution <b><span style="color: yellow;">Time: 26261.145 ms</span></b>
</pre>

# 900MB - $.records[\*].address.city 

<pre>
Aggregate  (cost=27022.01..27022.02 rows=1 width=8) (actual time=38031.435..38031.437 rows=1 loops=1)
   Output: count(*)
   Buffers: shared hit=3 read=39494 written=16081, temp read=13892 written=13892
   ->  Nested Loop  (cost=0.01..24022.01 rows=1200000 width=0) (actual time=37570.577..37939.788 rows=4000000 loops=1)
         Buffers: shared hit=3 read=39494 written=16081, temp read=13892 written=13892
         ->  Seq Scan on public.bench_json p  (cost=0.00..22.00 rows=1200 width=32) (actual time=0.005..0.009 rows=1 loops=1)
               Output: p.id, p.data
               Buffers: shared hit=1
         ->  Function Scan on public.<span style="color: red;">rsonpath_ext_str</span>  (cost=0.01..10.01 rows=1000 width=0) (actual <span style="color: red;">time=37570.569</span>..37800.410 rows=4000000 loops=1)
               Output: rsonpath_ext_str.idx, rsonpath_ext_str.val
               Function Call: rsonpath_ext_str('$.records[*].address.city'::text, (p.data)::text)
               Buffers: shared hit=2 read=39494 written=16081, temp read=13892 written=13892
 Planning:
   Buffers: shared hit=2 read=1
 Planning Time: 0.080 ms
 <b><span style="color: yellow;">Execution Time: 38115.574 ms</span></b>

</pre>

# 900MB - $.records[\*].scores[\*]

<pre>
Aggregate  (cost=27022.01..27022.02 rows=1 width=8) (actual time=47883.915..47883.918 rows=1 loops=1)
   Output: count(*)
   Buffers: shared hit=3 read=39494 written=16081, temp read=45938 written=45938
   ->  Nested Loop  (cost=0.01..24022.01 rows=1200000 width=0) (actual time=46018.433..47509.171 rows=17996508 loops=1)
         Buffers: shared hit=3 read=39494 written=16081, temp read=45938 written=45938
         ->  Seq Scan on public.bench_json p  (cost=0.00..22.00 rows=1200 width=32) (actual time=0.005..0.013 rows=1 loops=1)
               Output: p.id, p.data
               Buffers: shared hit=1
         ->  Function Scan on public.<span style="color: red;">rsonpath_ext_str</span>  (cost=0.01..10.01 rows=1000 width=0) (actual <span style="color: red;">time=46018.425</span>..46930.426 rows=17996508 loops=1)
               Output: rsonpath_ext_str.idx, rsonpath_ext_str.val
               Function Call: rsonpath_ext_str('$.records[*].scores[*]'::text, (p.data)::text)
               Buffers: shared hit=2 read=39494 written=16081, temp read=45938 written=45938
 Planning:
   Buffers: shared hit=2 read=1
 Planning Time: 0.079 ms
 <b><span style="color: yellow;">Execution Time: 47994.733 ms</span></b>

</pre>
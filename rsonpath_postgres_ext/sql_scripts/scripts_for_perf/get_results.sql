
SELECT
    query_path AS query,
    method,
    min(json_size_mb) AS json_size_mb,
    -- min(match_count) AS match_count,
    round(avg(elapsed_ms), 3) AS avg_ms
    -- round(min(elapsed_ms), 3) AS min_ms,
    -- round(max(elapsed_ms), 3) AS max_ms
    -- round(stddev_samp(elapsed_ms), 3) AS stddev_ms
FROM bench_results
GROUP BY query, method
ORDER BY query, method;
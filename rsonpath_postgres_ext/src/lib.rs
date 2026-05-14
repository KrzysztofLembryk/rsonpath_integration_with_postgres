use pgrx::prelude::*;

::pgrx::pg_module_magic!(name, version);

use std::time::Instant;
use rsonpath::input::BorrowedBytes;
use rsonpath::result::Match;
use rsonpath::{
    engine::{Compiler, Engine, RsonpathEngine},
};
use pgrx::iter::TableIterator;

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_ext_str(
    query: &str,
    json_str: &str,
) -> TableIterator<'static, (name!(idx, i64), name!(val, String))> 
{
    let sink_vec = run_qeury(query, json_str);

    let results_iter  = sink_vec.into_iter()
        .enumerate()
        .map(|(i, val)| (i as i64, String::from_utf8_lossy(val.bytes()).into_owned()));

    TableIterator::new(results_iter)
}

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_ext_str_timed(
    query: &str,
    json_str: &str,
) -> TableIterator<'static, (name!(idx, i64), name!(val, String))> 
{
    let now = Instant::now();
    let sink_vec = run_qeury(query, json_str);
    let elapsed_run_query = now.elapsed();

    pgrx::notice!("rsonpath_str took: {:?}", elapsed_run_query);

    let now = Instant::now();
    let results_iter = sink_vec.into_iter()
        .enumerate()
        .map(|(i, val)| (i as i64, String::from_utf8_lossy(val.bytes()).into_owned()));
    let elapsed_aggregate_results = now.elapsed();

    pgrx::notice!("results_str aggregation took: {:?}", elapsed_aggregate_results);

    return TableIterator::new(results_iter);
}

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_ext_json(
    query: &str, 
    json_str: &str
) -> TableIterator<'static, (name!(idx, i64), name!(val, pgrx::Json))> 
{
    let sink_vec = run_qeury(query, json_str);

    let results_iter = sink_vec.into_iter()
        .enumerate()
        .map(|(i, val)| {
            let parsed_json = serde_json::from_slice(val.bytes()).unwrap();
            (i as i64, pgrx::Json(parsed_json))
        });

    return TableIterator::new(results_iter);
}


#[pg_extern(immutable, parallel_safe)]
fn rsonpath_ext_json_timed(
    query: &str, 
    json_str: &str
) -> TableIterator<'static, (name!(idx, i64), name!(val, pgrx::Json))> 
{
    let now = Instant::now();
    let sink_vec = run_qeury(query, json_str);
    let elapsed_run_query = now.elapsed();

    pgrx::notice!("rsonpath_json took: {:?}", elapsed_run_query);

    let now = Instant::now();
    let results_iter = sink_vec.into_iter()
        .enumerate()
        .map(|(i, val)| {
            let parsed_json = serde_json::from_slice(val.bytes()).unwrap();
            (i as i64, pgrx::Json(parsed_json))
        });
    let elapsed_aggregate_results = now.elapsed();

    pgrx::notice!("results_json aggregation took: {:?}", elapsed_aggregate_results);

    return TableIterator::new(results_iter);
}

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_ext_jsonb(
    query: &str, 
    json_str: &str
) -> TableIterator<'static, (name!(idx, i64), name!(val, pgrx::JsonB))> 
{
    let sink_vec = run_qeury(query, json_str);

    let results: Vec<(i64, pgrx::JsonB)> = sink_vec.iter()
        .enumerate()
        .map(|(i, val)| {
            let raw = String::from_utf8_lossy(val.bytes()).into_owned();
            (i as i64, pgrx::JsonB(serde_json::from_str(&raw).unwrap()))
        })
        .collect();

    return TableIterator::new(results);
}

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_ext_count(query: &str, json_str: &str) -> i64
{
    let query = rsonpath_syntax::parse(query).expect("query parse error");
    let input = BorrowedBytes::new(json_str.as_bytes());
    let engine = RsonpathEngine::compile_query(&query).expect("engine compile error");

    engine.count(&input).expect("engine count error") as i64
}

fn run_qeury(query: &str, json_str: &str) -> Vec<Match>
{
    let query = rsonpath_syntax::parse(query).expect("query parse error");
    let input = BorrowedBytes::new(json_str.as_bytes());
    let engine = RsonpathEngine::compile_query(&query).expect("engine compile error");
    let mut sink_vec = Vec::new();
    engine.matches(&input, &mut sink_vec)
        .expect("Engine count error");

    return sink_vec;
}


fn check_if_subjson_exists(json_str: &str, query: &str) -> bool
{
    let query = rsonpath_syntax::parse(query).expect("query parse error");
    let input = BorrowedBytes::new(json_str.as_bytes());
    let engine = RsonpathEngine::compile_query(&query).expect("engine compile error");

    return engine.count(&input).expect("engine count error") as i64 > 0;
}

#[pg_extern(immutable, parallel_safe, strict)] 
#[opname(@@)] // operator symbol in SQL
fn rsonpath_contains(json_str: &str,query: &str) -> bool {
    // We pass whole json from row, then we check if at there is at least one sub-json 
    // that satisfies query. 
    // We Return true if there is.
    // Currently we would need to use count to accomplish this.
    // But to make it more optimal, we would need a function that stops once it finds
    // first match
    return check_if_subjson_exists(json_str, query);
}


#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    // sprawdzic czy maja rzeczy do benchmarkowania w pgrx
    use pgrx::prelude::*;
    use std::fmt::Write as FmtWrite;
    use std::time::Instant;

    const TABLE_NAME: &str = "json_table";
    const JSON_COL_NAME: &str = "json";
    const JSONB_COL_NAME: &str = "jsonb";
    const N_ITERS: usize = 3;
    const ONE_MB: f64 = (1024 * 1024) as f64;

    const EXTENSIONS: &'static [&'static str] = &[
        "rsonpath_ext_json",
        "rsonpath_ext_str",
        "rsonpath_ext_count",
        // "jsonpath",
        ];
    const SMALL_JSON: &str = include_str!("../tests/testdata/small.json");
    const MEDIUM_JSON: &str = include_str!("../tests/testdata/medium.json");
    const LARGE_JSONS: &'static [&'static str] = &[
        concat!(env!("CARGO_MANIFEST_DIR"), "/tests/testdata/large.json",), 
        ];
    


    const PERF_RESULTS_PATH: &str = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/results/perf_results.txt"
    );

    fn load_json(path: &str) -> String
    {
        return std::fs::read_to_string(path).unwrap_or_else(|err| {
            panic!(
                "Failed to read {}. ERROR: {}\nRun: python3 tests/testdata/generate_testdata.py", path, err
            )
        });
    }

    struct TestCase {
        name: &'static str,
        query: &'static str,
        json: &'static str,
        expected: Expected,
    }

    #[allow(dead_code)]
    enum Expected {
        Json(&'static str),
        Count(usize),
        Nothing
    }

    const TEST_CASES: &[TestCase] = &[
        TestCase {
            name: "simple_key",
            query: "$.person.name",
            json: SMALL_JSON,
            expected: Expected::Json(r#"["John"]"#),
        },
        TestCase {
            name: "nested_array_wildcard",
            query: "$.person.phoneNumbers[*].number",
            json: SMALL_JSON,
            expected: Expected::Json(r#"["111-222-333","123-456-789"]"#),
        },
        TestCase {
            name: "no_match",
            query: "$.nonexistent",
            json: SMALL_JSON,
            expected: Expected::Json("[]"),
        },
        TestCase {
            name: "array_index",
            query: "$.person.phoneNumbers[0].type",
            json: SMALL_JSON,
            expected: Expected::Json(r#"["Home"]"#),
        },
        TestCase {
            name: "descendant_search",
            query: "$..number",
            json: SMALL_JSON,
            expected: Expected::Json(r#"["111-222-333","123-456-789"]"#),
        },
        TestCase {
            name: "medium_all_names",
            query: "$..name",
            json: MEDIUM_JSON,
            expected: Expected::Count(25),
        },
        TestCase {
            name: "medium_all_prices",
            query: "$..price",
            json: MEDIUM_JSON,
            expected: Expected::Count(12),
        },
        TestCase {
            name: "medium_deep_path",
            query: "$.store.departments[0].products[0].reviews[0].text",
            json: MEDIUM_JSON,
            expected: Expected::Json(r#"["Excellent"]"#),
        },
    ];

    const TEST_CASES_LARGE: &[TestCase] = &[
        TestCase {
            name: "not_nested_simple_key",
            query: "$.records[*].name",
            json: "",
            expected: Expected::Nothing,
        },
        TestCase {
            name: "array_wildcard",
            query: "$.records[*].scores[*]",
            json: "",
            expected: Expected::Nothing,
        },
        TestCase {
            name: "nested_key",
            query: "$.records[*].address.city",
            json: "",
            expected: Expected::Nothing,
        },
    ];

    fn escape_sql(s: &str) -> String {
        s.replace('\'', "''")
    }

    // Collect all result rows from a query.
    // Works for both single-value and SetOfIterator return types.
    fn run_sql_query(sql: &str) -> Vec<String> 
    {
        Spi::connect(|client| {
            let tup_table = client.select(sql, None, &[]).expect("SPI query failed");
            let mut results = Vec::new();
            for row in tup_table {
                if let Some(val) = row.get::<String>(1).expect("column read error") {
                    results.push(val);
                }
            }
            return results;
        })
    }

    fn run_sql_query_discard_results(sql: &str) 
    {
        Spi::connect(|client| {
                client.select(sql, None, &[]).expect("SPI query failed");
        })
    }

    // TODO: we should create a struct that knows table columns etc, instead of 
    // passing here two col names
    fn build_sql(
        ext_name: &str, 
        query: &str, 
        json_table_name: &str,
        json_data_col_name: &str,
        jsonb_data_col_name: &str,
    ) -> String 
    {
        if ext_name == "jsonpath"
        {
            return format!(
                "
                SELECT count(*)
                FROM {} jt,
                    LATERAL jsonb_path_query(jt.{}, '{}'::jsonpath);
                ",
                escape_sql(json_table_name), jsonb_data_col_name, escape_sql(query)
            );
        }
        else if ext_name == "rsonpath_ext_count"
        {
            return format!(
                "
                SELECT sum(rsonpath_ext_count('{}', jt.{}::text))
                FROM {} jt;
                ",
                escape_sql(query), json_data_col_name, escape_sql(json_table_name)
            );
        }
        else
        {
            return format!(
                "
                SELECT count(*)
                FROM {} jt,
                    LATERAL {}('{}', jt.{}::text);
                ",
                escape_sql(json_table_name), ext_name, escape_sql(query), json_data_col_name
            );
        }
    }

    // == Correctness ==

    // Inline SQL for correctness: returns actual values, not count(*).
    // Cast to text so it works for str, json, and jsonb return types.
    fn build_inline_sql(ext_name: &str, query: &str, json: &str) -> String {
        format!(
            "SELECT val::text FROM {}('{}', '{}')",
            ext_name,
            escape_sql(query),
            escape_sql(json)
        )
    }

    fn check_case(case: &TestCase) {
        for ext_name in EXTENSIONS {
            let sql = build_inline_sql(ext_name, case.query, case.json);
            let results = run_sql_query(&sql);

            match &case.expected {
                Expected::Json(expected_str) => {
                    let want: serde_json::Value = serde_json::from_str(expected_str)
                        .unwrap_or_else(|e| panic!("[{}/{}] bad expected JSON: {}", ext_name, case.name, e));
                    let want_arr = want.as_array()
                        .unwrap_or_else(|| panic!("[{}/{}] expected must be a JSON array", ext_name, case.name));

                    let got: Vec<serde_json::Value> = results.iter()
                        .map(|r| serde_json::from_str(r)
                            .unwrap_or_else(|e| panic!("[{}/{}] bad result JSON '{}': {}", ext_name, case.name, r, e)))
                        .collect();

                    assert_eq!(got.len(), want_arr.len(),
                        "[{}/{}] result count mismatch: got {}, want {}",
                        ext_name, case.name, got.len(), want_arr.len());
                    assert_eq!(got, *want_arr, "[{}/{}] values mismatch", ext_name, case.name);
                },
                Expected::Count(n) => {
                    assert_eq!(results.len(), *n,
                        "[{}/{}] count mismatch: got {}, want {}",
                        ext_name, case.name, results.len(), n);
                },
                Expected::Nothing => {}
            }
        }
    }

    #[pg_test]
    fn test_correctness() {
        for case in TEST_CASES {
            check_case(case);
        }
    }

    #[pg_test]
    fn test_correctness_via_table() {
        Spi::run("CREATE TABLE test_json (id serial, data json)").unwrap();
        Spi::run(&format!(
            "INSERT INTO test_json (data) VALUES ('{}')",
            escape_sql(SMALL_JSON)
        )).unwrap();

        for ext_name in EXTENSIONS {
            let sql = format!(
                "SELECT val::text FROM {}('$.person.name', (SELECT data::text FROM test_json WHERE id = 1))",
                ext_name
            );
            let results = run_sql_query(&sql);
            assert_eq!(results.len(), 1, "[{}/via_table] expected 1 result", ext_name);
            let got: serde_json::Value = serde_json::from_str(&results[0]).unwrap();
            let want: serde_json::Value = serde_json::from_str("\"John\"").unwrap();
            assert_eq!(got, want, "[{}/via_table] mismatch", ext_name);
        }
    }

    #[pg_test]
    fn test_correctness_large() {
        for json_path in LARGE_JSONS {
            let large = load_json(json_path);
            for ext_name in EXTENSIONS {
                for (query, min_expected) in &[
                    ("$..name", 1000),
                    ("$..city", 1000),
                    ("$..id", 1000),
                ] {
                    let sql = build_inline_sql(ext_name, query, &large);
                    let results = run_sql_query(&sql);
                    assert!(results.len() >= *min_expected,
                        "[{}/large/{}] expected >= {} results, got {}",
                        ext_name, query, min_expected, results.len());
                }
            }
        }
    }

    // == Performance ==

    fn bench(sql: &str, warmup: usize, iters: usize) -> f64 
    {
        for _ in 0..warmup {
            let _ = run_sql_query(sql);
        }
        let start = Instant::now();
        for _ in 0..iters {
            let _ = run_sql_query(sql);
        }
        start.elapsed().as_secs_f64() * 1000.0 / iters as f64
    }

    fn bench_and_discard_results(sql: &str, warmup: usize, iters: usize) -> f64 
    {
        for _ in 0..warmup {
            run_sql_query_discard_results(sql);
        }
        let start = Instant::now();
        for _ in 0..iters {
            run_sql_query_discard_results(sql);
        }
        return start.elapsed().as_secs_f64() * 1000.0 / iters as f64;
    }

    /// The schema of the generated table is dynamically constructed based on the
    /// provided column names. By conditionally supplying `Some` or `None` for 
    /// `json_col_name` and `jsonb_col_name`, you can control exactly which data 
    /// types are in the table:
    /// 
    /// * Supplying `Some` for both creates a table with both `JSON` AND `JSONB` 
    /// columns.
    /// * Supplying `Some` for one and `None` for the other yields a table 
    /// exclusively containing that specific data type.
    /// * Supplying `None` for both arguments is invalid and will trigger a panic.
    /// 
    /// * `disable_toast` - If set to `true`, alters the column storage strategy to 
    /// `EXTERNAL`, effectively disabling default TOAST compression (pglz/lz4) to 
    ///  isolate query performance.
    fn create_json_table(
        table_name: &str, 
        json_col_name: Option<&str>, 
        jsonb_col_name: Option<&str>,
        disable_toast: bool
    ) -> f64
    {
        let start = Instant::now();
        let mut table_create_cmd = format!("
                CREATE TABLE {table_name} (
                id SERIAL PRIMARY KEY,");

        if let (Some(json_col), Some(jsonb_col)) = (json_col_name, jsonb_col_name)
        {
            table_create_cmd = format!(
                "
                    {table_create_cmd}\n
                    {json_col} JSON,\n
                    {jsonb_col} JSONB);
                "
            );

            if disable_toast
            {
                table_create_cmd = format!("{table_create_cmd}\n
                ALTER TABLE {table_name} ALTER COLUMN {json_col} SET STORAGE EXTERNAL;\n
                ALTER TABLE {table_name} ALTER COLUMN {jsonb_col} SET STORAGE EXTERNAL;")
            }
        }
        else if let Some(json_col) = json_col_name
        {
            table_create_cmd = format!("
                {table_create_cmd}\n
                {json_col} JSON);
            ");

            if disable_toast
            {
                table_create_cmd = format!("{table_create_cmd}\n
                ALTER TABLE {table_name} ALTER COLUMN {json_col} SET STORAGE EXTERNAL;")
            }
        }
        else if let Some(jsonb_col) = jsonb_col_name
        {
            table_create_cmd = format!("
                {table_create_cmd}\n
                {jsonb_col} JSONB);
            ");
            if disable_toast
            {
                table_create_cmd = format!("{table_create_cmd}\n
                ALTER TABLE {table_name} ALTER COLUMN {jsonb_col} SET STORAGE EXTERNAL;")
            }
        }
        else
        {
            panic!("create_json_table got json_col and jsonb_col both NONE");
        }

        Spi::run(&table_create_cmd).expect(&format!("Failed to create table: {} with json and jsonb cols", table_name));
        return start.elapsed().as_secs_f64() * 1000.0;
    }

    fn drop_json_table(table_name: &str)
    {
        Spi::run(&format!(
            "DROP TABLE {};", 
            table_name)
        ).expect(&format!("Failed to drop table: {}", table_name));
    }

    fn insert_data_into_json_table(
        table_name: &str, 
        json_col_name: Option<&str>, 
        jsonb_col_name: Option<&str>, 
        data: &str
    ) -> f64
    {
        let start = Instant::now();

        let mut insert_cmd = format!("
                INSERT INTO {table_name} ");

        if let (Some(json_col), Some(jsonb_col)) = (json_col_name, jsonb_col_name)
        {
            insert_cmd = format!("{insert_cmd}({json_col},{jsonb_col}) VALUES ('{}', '{}');", escape_sql(data), escape_sql(data));
        }
        else if let Some(json_col) = json_col_name
        {
            insert_cmd = format!("{insert_cmd}({json_col}) VALUES ('{}');", escape_sql(data));
        }
        else if let Some(jsonb_col) = jsonb_col_name
        {
            insert_cmd = format!("{insert_cmd}({jsonb_col}) VALUES ('{}');", escape_sql(data));
        }
        else
        {
            panic!("create_json_table got json_col and jsonb_col both NONE");
        }

        Spi::run(&insert_cmd).expect(&format!("Failed to create table: {} with json and jsonb cols", table_name));

        return start.elapsed().as_secs_f64() * 1000.0;
    }

    macro_rules! init_test {
        (
            $title:expr, 
            $report:ident, 
            $table_name:ident, 
            $json_col_name:ident, 
            $jsonb_col_name:ident, 
            $large_jsons:ident, 
            $table_op_times:ident
        ) => {
            let mut $report = String::new();
            let timestamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();

            writeln!($report, "{} (epoch: {})", $title, timestamp).unwrap();
            writeln!($report, "{:<55} {:>12} {:>10} {:>12}",
                "Test", "JSON MB", "Iters", "Avg (ms)").unwrap();
            writeln!($report, "{}", "-".repeat(80)).unwrap();

            let $table_name = TABLE_NAME;
            let $json_col_name = JSON_COL_NAME;
            let $jsonb_col_name = JSONB_COL_NAME;
            let $large_jsons = get_all_large_jsons("/tests/testdata/");
            let mut $table_op_times: Vec<(String, f64, f64)> = vec![];
        };
    }

    macro_rules! prepare_table {
        (
            $json_path:expr,
            $table_name:expr,
            $json_col_name:expr,
            $jsonb_col_name:expr,
            $disable_toast:expr,
            $large_json:ident,
            $json_size_mb:ident,
            $creation_time:ident,
            $insertion_time:ident,
            $table_op_times:expr
    
        ) => {

            let $large_json = load_json($json_path);
            let $json_size_mb = ($large_json.len() as f64) / ONE_MB;

            let $creation_time = create_json_table(
                    $table_name, 
                    $json_col_name, 
                    $jsonb_col_name,
                    $disable_toast
                );
            let $insertion_time = insert_data_into_json_table(
                $table_name, 
                $json_col_name, 
                $jsonb_col_name, 
                &$large_json
            );

            $table_op_times.push((
                String::from($json_path), 
                $creation_time, 
                $insertion_time
            ));
        };
    }

    #[pg_test]
    fn test_performance_large_no_toast()
    {
        let disable_toast = true;

        init_test!(
            "Test performance no TOAST", 
            report, 
            table_name, 
            json_col_name, 
            jsonb_col_name, 
            large_jsons, 
            table_op_times
        );

        for json_path in large_jsons.iter()
        {
            prepare_table!(
                json_path,
                table_name,
                Some(json_col_name),
                Some(jsonb_col_name),
                disable_toast,
                large_json,
                json_size_mb,
                creation_time,
                insertion_time,
                table_op_times
            );

            for test_case in TEST_CASES_LARGE 
            {
                for ext_name in EXTENSIONS
                {
                    pgrx::info!("START: {}#{}", ext_name, test_case.name);
                    let query = test_case.query;
                    let sql = build_sql(
                        *ext_name, 
                        query, 
                        table_name,  
                        json_col_name,
                        jsonb_col_name,
                    );
                    let iters = N_ITERS;
                    let warmup_iters = 1;
                    let avg_ms = bench_and_discard_results(&sql, warmup_iters, iters);

                    writeln!(report, "{:<55} {:>12.2} {:>10} {:>12.4}",
                        format!("{}# {}", ext_name, query), 
                        json_size_mb, 
                        iters, 
                        avg_ms
                    ).unwrap();
                }
                
            }
            drop_json_table(table_name);
        }

        for op_time in table_op_times.iter()
        {
            writeln!(report, "JSON: {}\n --creation_time: {:.2} ms\n --insertion_time: {:.2} ms", op_time.0, op_time.1, op_time.2).unwrap();
        }

        std::fs::write(PERF_RESULTS_PATH, &report).unwrap_or_else(|e| {
            panic!("Failed to write perf results to {}: {}", PERF_RESULTS_PATH, e)
        });
    }

    #[pg_test]
    fn test_performance_large() 
    {
        init_test!(
            "Test performance large", 
            report, 
            table_name, 
            json_col_name, 
            jsonb_col_name, 
            large_jsons, 
            table_op_times
        );

        for json_path in large_jsons.iter()
        {
            prepare_table!(
                json_path,
                table_name,
                Some(json_col_name),
                Some(jsonb_col_name),
                false,
                large_json,
                json_size_mb,
                creation_time,
                insertion_time,
                table_op_times
            );

            for test_case in TEST_CASES_LARGE 
            {
                for ext_name in EXTENSIONS
                {
                    pgrx::info!("START: {}#{}", ext_name, test_case.name);
                    let query = test_case.query;
                    let sql = build_sql(
                        *ext_name, 
                        query, 
                        table_name,  
                        json_col_name,
                        jsonb_col_name,
                    );
                    let iters = N_ITERS;
                    let warmup_iters = 1;
                    let avg_ms = bench_and_discard_results(&sql, warmup_iters, iters);

                    writeln!(report, "{:<55} {:>12.2} {:>10} {:>12.4}",
                        format!("{}# {}", ext_name, query), 
                        json_size_mb, 
                        iters, 
                        avg_ms
                    ).unwrap();
                }
                
            }
            drop_json_table(table_name);
        }

        for op_time in table_op_times.iter()
        {
            writeln!(report, "JSON: {}\n --creation_time: {:.2} ms\n --insertion_time: {:.2} ms", op_time.0, op_time.1, op_time.2).unwrap();
        }

        std::fs::write(PERF_RESULTS_PATH, &report).unwrap_or_else(|e| {
            panic!("Failed to write perf results to {}: {}", PERF_RESULTS_PATH, e)
        });
    }

    #[pg_test]
    fn test_performance_jsonpath() 
    {
        init_test!(
            "Jsonpath results", 
            report, 
            table_name, 
            json_col_name, 
            jsonb_col_name, 
            large_jsons, 
            table_op_times
        );

        for json_path in large_jsons.iter()
        {
            prepare_table!(
                json_path,
                table_name,
                Some(json_col_name),
                Some(jsonb_col_name),
                false,
                large_json,
                json_size_mb,
                creation_time,
                insertion_time,
                table_op_times
            );

            for test_case in TEST_CASES_LARGE 
            {
                let ext_name = "jsonpath";
                pgrx::info!("START: {}#{}", ext_name, test_case.name);

                let query = test_case.query;
                let sql = build_sql(
                    ext_name, 
                    query, 
                    table_name,  
                    json_col_name,
                    jsonb_col_name,
                );
                let iters = N_ITERS;
                let warmup_iters = 1;
                let avg_ms = bench_and_discard_results(&sql, warmup_iters, iters);

                writeln!(report, "{:<55} {:>12.2} {:>10} {:>12.4}",
                    format!("{}# {}", ext_name, query), 
                    json_size_mb, 
                    iters, 
                    avg_ms
                ).unwrap();
                
            }
            drop_json_table(table_name);
        }

        for op_time in table_op_times.iter()
        {
            writeln!(report, "JSON: {}\n --creation_time: {:.2} ms\n --insertion_time: {:.2} ms", op_time.0, op_time.1, op_time.2).unwrap();
        }

        std::fs::write(PERF_RESULTS_PATH, &report).unwrap_or_else(|e| {
            panic!("Failed to write perf results to {}: {}", PERF_RESULTS_PATH, e)
        });
    }

    fn get_all_large_jsons(data_path: &str) -> Vec<String>
    {
        let data_path = data_path.strip_prefix("/").map_or(data_path, |s| s);
        let dir_path = format!("{}/{}", env!("CARGO_MANIFEST_DIR"), data_path);
        let dir_entries = std::fs::read_dir(dir_path).unwrap();
        let mut large_jsons = vec![];
        // (?i)             - Case-insensitive flag
        // (?:^|[^a-z])     - Matches the start of the string OR any non-letter (allows '_', '-', etc.)
        // large            - The exact word
        // (?:[^a-z].*)?    - Matches a non-letter immediately after 'large', followed by anything
        // \.json$           - Ensures the string ends exactly with '.json'
        let re = regex::Regex::new(r"(?i)(?:^|[^a-z])large(?:[^a-z].*)?\.json$").unwrap();

        for dir_entry in dir_entries
        {
            if let Ok(dir_entry) = dir_entry
            {
                let path = String::from(dir_entry.path().to_str().unwrap());

                if re.is_match(&path)
                {
                    large_jsons.push(path);
                }
            }
        }

        return large_jsons;
    }


    // #[pg_test]
    // fn test_performance_med_small() 
    // {
    //     let mut report = String::new();
    //     let timestamp = std::time::SystemTime::now()
    //         .duration_since(std::time::UNIX_EPOCH)
    //         .unwrap()
    //         .as_secs();
    //     writeln!(report, "# perf results (epoch: {})", timestamp).unwrap();
    //     writeln!(report, "{:<35} {:>12} {:>10} {:>12}",
    //         "Test", "JSON bytes", "Iters", "Avg (ms)").unwrap();
    //     writeln!(report, "{}", "-".repeat(73)).unwrap();

    //     for ext_name in EXTENSIONS
    //     {
    //         for case in TEST_CASES {
    //             let sql = build_sql(*ext_name, case.query, case.json);
    //             let json_bytes = case.json.len();
    //             let iters = 100;
    //             let avg_ms = bench(&sql, 5, iters);
    //             writeln!(report, "{:<35} {:>12} {:>10} {:>12.4}",
    //                 case.name, json_bytes, iters, avg_ms).unwrap();
    //         }
    //     }

    //     std::fs::write(PERF_RESULTS_PATH, &report).unwrap_or_else(|e| {
    //         panic!("Failed to write perf results to {}: {}", PERF_RESULTS_PATH, e)
    //     });
    // }
}

#[cfg(test)]
pub mod pg_test {
    pub fn setup(_options: Vec<&str>) {}

    #[must_use]
    pub fn postgresql_conf_options() -> Vec<&'static str> {
        vec![]
    }
}

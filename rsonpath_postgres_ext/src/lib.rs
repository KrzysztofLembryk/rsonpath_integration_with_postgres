use pgrx::prelude::*;

::pgrx::pg_module_magic!(name, version);

use std::time::Instant;
use rsonpath::input::BorrowedBytes;
use rsonpath::result::Match;
use rsonpath::{
    engine::{Compiler, Engine, RsonpathEngine},
};
use pgrx::iter::TableIterator;

#[pg_extern]
fn rsonpath_ext_str(
    query: &str,
    json_str: &str,
) -> TableIterator<'static, (name!(idx, i64), name!(val, String))> 
{
    let sink_vec = run_qeury(query, json_str);

    let results: Vec<(i64, String)> = sink_vec.into_iter()
        .enumerate()
        .map(|(i, val)| (i as i64, String::from_utf8_lossy(val.bytes()).into_owned()))
        .collect();

    TableIterator::new(results)
}

#[pg_extern]
fn rsonpath_ext_str_timed(
    query: &str,
    json_str: &str,
) -> TableIterator<'static, (name!(idx, i64), name!(val, String))> 
{
    let now = Instant::now();
    let sink_vec = run_qeury(query, json_str);
    let elapsed_run_query = now.elapsed();

    pgrx::notice!("rsonpath took: {:?}", elapsed_run_query);

    let now = Instant::now();
    let results: Vec<(i64, String)> = sink_vec.into_iter()
        .enumerate()
        .map(|(i, val)| (i as i64, String::from_utf8_lossy(val.bytes()).into_owned()))
        .collect();
    let elapsed_aggregate_results = now.elapsed();

    pgrx::notice!("results aggregation took: {:?}", elapsed_aggregate_results);

    TableIterator::new(results)
}

#[pg_extern]
fn rsonpath_ext_json(
    query: &str, 
    json_str: &str
) -> TableIterator<'static, (name!(idx, i64), name!(val, pgrx::Json))> 
{
    let sink_vec = run_qeury(query, json_str);

    let results: Vec<(i64, pgrx::Json)> = sink_vec.iter()
        .enumerate()
        .map(|(i, val)| {
            let raw = String::from_utf8_lossy(val.bytes()).into_owned();
            (i as i64, pgrx::Json(serde_json::from_str(&raw).unwrap()))
        })
        .collect();

    return TableIterator::new(results);
}


#[pg_extern]
fn rsonpath_ext_json_timed(
    query: &str, 
    json_str: &str
) -> TableIterator<'static, (name!(idx, i64), name!(val, pgrx::Json))> 
{
    let now = Instant::now();
    let sink_vec = run_qeury(query, json_str);
    let elapsed_run_query = now.elapsed();

    pgrx::notice!("rsonpath took: {:?}", elapsed_run_query);

    let now = Instant::now();
    let results: Vec<(i64, pgrx::Json)> = sink_vec.iter()
        .enumerate()
        .map(|(i, val)| {
            let raw = String::from_utf8_lossy(val.bytes()).into_owned();
            (i as i64, pgrx::Json(serde_json::from_str(&raw).unwrap()))
        })
        .collect();
    let elapsed_aggregate_results = now.elapsed();

    pgrx::notice!("results aggregation took: {:?}", elapsed_aggregate_results);

    return TableIterator::new(results);
}

#[pg_extern]
fn rsonpath_ext_table_iter_jsonb(
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

#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    // sprawdzic czy maja rzeczy do benchmarkowania w pgrx
    use pgrx::prelude::*;
    use std::fmt::Write as FmtWrite;
    use std::time::Instant;

    const ONE_MB: f64 = (1024 * 1024) as f64;
    const EXTENSIONS: &'static [&'static str] = &[
        "rsonpath_ext_json" ,
        "rsonpath_ext_str",
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

    // fn check_case(case: &TestCase, ext_name: &str) 
    // {
    //     let sql = build_sql(ext_name, case.query, case.json);
    //     let results = run_sql_query(&sql);

    //     match &case.expected {
    //         Expected::Json(expected_str) => {
    //             assert!(!results.is_empty(), "[{}] got no results", case.name);
    //             let got: serde_json::Value = serde_json::from_str(&results[0])
    //                 .unwrap_or_else(|e| panic!("[{}] bad JSON output: {}", case.name, e));
    //             let want: serde_json::Value = serde_json::from_str(expected_str)
    //                 .unwrap_or_else(|e| panic!("[{}] bad JSON expected: {}", case.name, e));
    //             assert_eq!(got, want, "[{}] mismatch", case.name);
    //         },
    //         Expected::Count(n) => {
    //             assert!(!results.is_empty(), "[{}] got no results", case.name);
    //             let got: serde_json::Value = serde_json::from_str(&results[0])
    //                 .unwrap_or_else(|e| panic!("[{}] bad JSON output: {}", case.name, e));
    //             let arr = got.as_array()
    //                 .unwrap_or_else(|| panic!("[{}] expected array", case.name));
    //             assert_eq!(arr.len(), *n, "[{}] count mismatch", case.name);
    //         },
    //         Expected::Nothing => {}
    //     }
    // }

    // #[pg_test]
    // fn test_correctness() 
    // {
    //     for ext_name in EXTENSIONS.iter()
    //     {
    //         for case in TEST_CASES 
    //         {
    //             check_case(case, *ext_name);
    //         }
    //     }
    // }

    // #[pg_test]
    // fn test_correctness_via_table() 
    // {
    //     Spi::run("CREATE TABLE test_json (id serial, data json)").unwrap();
    //     Spi::run(&format!(
    //         "INSERT INTO test_json (data) VALUES ('{}')",
    //         escape_sql(SMALL_JSON)
    //     )).unwrap();

    //     for ext_name in EXTENSIONS
    //     {
    //         let results = run_sql_query(
    //             &format!("SELECT {}('$.person.name', data::text) FROM test_json WHERE id = 1", ext_name)
    //         );
    //         let got: serde_json::Value = serde_json::from_str(&results[0]).unwrap();
    //         let want: serde_json::Value = serde_json::from_str(r#"["John"]"#).unwrap();
    //         assert_eq!(got, want);
    //     }
    // }

    // #[pg_test]
    // fn test_correctness_large() 
    // {
    //     for json_path in LARGE_JSONS
    //     {
    //         let large = load_json(*json_path);
    //         for ext_name in EXTENSIONS
    //         {
    //             for query in &["$..name", "$..city", "$..id"] 
    //             {
    //                 let sql = build_sql(*ext_name, query, &large);
    //                 let results = run_sql_query(&sql);

    //                 assert!(!results.is_empty(), "[large {}] got no results", query);

    //                 let got: serde_json::Value = serde_json::from_str(&results[0])
    //                     .unwrap_or_else(|e| panic!("[large {}] bad JSON: {}", query, e));
    //                 let arr = got.as_array()
    //                     .unwrap_or_else(|| panic!("[large {}] expected array", query));

    //                 assert!(!arr.is_empty(), "[large {}] empty result array", query);
    //             }
    //         }
    //     }
    // }

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

    fn create_json_table(
        table_name: &str, 
        json_col_name: &str, 
        jsonb_col_name: &str
    ) -> f64
    {
        let start = Instant::now();

        Spi::run(&format!(
            "CREATE TABLE {} (
            id SERIAL PRIMARY KEY,
            {} JSON,
            {} JSONB
             );", 
            table_name, json_col_name, jsonb_col_name)
        ).expect(&format!("Failed to create table: {}", table_name));

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
        json_col_name: &str, 
        jsonb_col_name: &str, 
        data: &str
    ) -> f64
    {
        let start = Instant::now();

        Spi::run(&format!(
            "INSERT INTO {} ({}, {}) VALUES ('{}', '{}');",
            table_name,
            json_col_name,
            jsonb_col_name,
            escape_sql(data),
            escape_sql(data)
        )).expect("insert_data_into_json_table:: Failed to insert JSON data");

        return start.elapsed().as_secs_f64() * 1000.0;
    }

    #[pg_test]
    fn test_performance_large() 
    {
        // Spi::run("SET client_min_messages = WARNING;").unwrap();

        let mut report = String::new();
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        writeln!(report, "# perf results (epoch: {})", timestamp).unwrap();
        writeln!(report, "{:<55} {:>12} {:>10} {:>12}",
            "Test", "JSON MB", "Iters", "Avg (ms)").unwrap();
        writeln!(report, "{}", "-".repeat(80)).unwrap();

        let table_name: &str = "json_table";
        let json_col_name: &str = "json";
        let jsonb_col_name: &str = "jsonb";
        let mut table_op_times: Vec<(String, f64, f64)> = vec![];

        for json_path in LARGE_JSONS
        {
            let large_json = load_json(*json_path);
            let json_size_mb = (large_json.len() as f64) / ONE_MB;

            let creation_time = create_json_table(table_name, json_col_name, jsonb_col_name);
            let insertion_time = insert_data_into_json_table(table_name, json_col_name, jsonb_col_name, &large_json);

            table_op_times.push((
                String::from(*json_path), 
                creation_time, 
                insertion_time
            ));

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
                    let iters = 5;
                    let avg_ms = bench_and_discard_results(&sql, 1, iters);

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

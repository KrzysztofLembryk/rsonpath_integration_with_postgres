use pgrx::prelude::*;

::pgrx::pg_module_magic!(name, version);

use rsonpath::input::BorrowedBytes;
use rsonpath::result::Match;
use rsonpath::{
    engine::{Compiler, Engine, RsonpathEngine},
};
use pgrx::iter::TableIterator;

#[pg_extern]
fn rsonpath_ext(query: &str, json_str: &str) -> String 
{
    let sink_vec = run_qeury(query, json_str);

    let values: Vec<serde_json::Value> = sink_vec.iter()
        .map(|val| serde_json::from_slice(val.bytes()).unwrap())
        .collect();

    return serde_json::to_string_pretty(&values).unwrap();
}
// 1) benchmark dla rsonpath_ext_table_iter_str i rsonpath_ext_table_iter_json
// plus porownac z operatorem jsonpath w postgresie
// 2) duzy json np. d3 dataset
#[pg_extern]
fn rsonpath_ext_table_iter_str(
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
fn rsonpath_ext_table_iter_json(
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
    use pgrx::prelude::*;
    use std::fmt::Write as FmtWrite;
    use std::time::Instant;

    const EXT_NAME: &str = "rsonpath_ext";

    const SMALL_JSON: &str = include_str!("../tests/testdata/small.json");
    const MEDIUM_JSON: &str = include_str!("../tests/testdata/medium.json");

    const PERF_RESULTS_PATH: &str = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/results/perf_results.txt"
    );

    const LARGE_JSON_PATH: &str = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/testdata/large.json"
    );

    fn load_large_json() -> String {
        std::fs::read_to_string(LARGE_JSON_PATH).unwrap_or_else(|e| {
            panic!(
                "Failed to read {}: {}\nRun: python3 tests/testdata/generate_testdata.py",
                LARGE_JSON_PATH, e
            )
        })
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

    struct LargeTestCase {
        pub name: &'static str,
        pub query: &'static str,
        pub expected: Expected,
    }

    const TEST_CASES_LARGE: &[LargeTestCase] = &[
        LargeTestCase {
            name: "simple_key",
            query: "$.person.name",
            expected: Expected::Json(r#"["John"]"#),
        },
        LargeTestCase {
            name: "nested_array_wildcard",
            query: "$.person.phoneNumbers[*].number",
            expected: Expected::Json(r#"["111-222-333","123-456-789"]"#),
        },
        LargeTestCase {
            name: "no_match",
            query: "$.nonexistent",
            expected: Expected::Json("[]"),
        },
        LargeTestCase {
            name: "array_index",
            query: "$.person.phoneNumbers[0].type",
            expected: Expected::Json(r#"["Home"]"#),
        },
        LargeTestCase {
            name: "descendant_search",
            query: "$..number",
            expected: Expected::Json(r#"["111-222-333","123-456-789"]"#),
        },
        LargeTestCase {
            name: "all_names",
            query: "$..name",
            expected: Expected::Count(25),
        },
        LargeTestCase {
            name: "all_prices",
            query: "$..price",
            expected: Expected::Count(12),
        },
        LargeTestCase {
            name: "deep_path",
            query: "$.store.departments[0].products[0].reviews[0].text",
            expected: Expected::Json(r#"["Excellent"]"#),
        },
    ];

    fn escape_sql(s: &str) -> String {
        s.replace('\'', "''")
    }

    // Collect all result rows from a query.
    // Works for both single-value and SetOfIterator return types.
    fn collect_results(sql: &str) -> Vec<String> {
        Spi::connect(|client| {
            let tup_table = client.select(sql, None, &[]).expect("SPI query failed");
            let mut results = Vec::new();
            for row in tup_table {
                if let Some(val) = row.get::<String>(1).expect("column read error") {
                    results.push(val);
                }
            }
            results
        })
    }

    fn run_qeury_discard_results(sql: &str) {
        Spi::connect(|client| {
                client.select(sql, None, &[]).expect("SPI query failed");
        })
    }

    fn build_sql(query: &str, json: &str) -> String {
        format!(
            "SELECT {}('{}', '{}')",
            EXT_NAME,
            escape_sql(query),
            escape_sql(json)
        )
    }

    fn build_sql2(ext_name: &str, query: &str, json_path: &str) -> String {
        format!(
            "SELECT {}('{}', '{}')",
            ext_name,
            escape_sql(query),
            escape_sql(json_path)
        )
    }

    // == Correctness ==

    fn check_case(case: &TestCase) {
        let sql = build_sql(case.query, case.json);
        let results = collect_results(&sql);

        match &case.expected {
            Expected::Json(expected_str) => {
                assert!(!results.is_empty(), "[{}] got no results", case.name);
                let got: serde_json::Value = serde_json::from_str(&results[0])
                    .unwrap_or_else(|e| panic!("[{}] bad JSON output: {}", case.name, e));
                let want: serde_json::Value = serde_json::from_str(expected_str)
                    .unwrap_or_else(|e| panic!("[{}] bad JSON expected: {}", case.name, e));
                assert_eq!(got, want, "[{}] mismatch", case.name);
            }
            Expected::Count(n) => {
                assert!(!results.is_empty(), "[{}] got no results", case.name);
                let got: serde_json::Value = serde_json::from_str(&results[0])
                    .unwrap_or_else(|e| panic!("[{}] bad JSON output: {}", case.name, e));
                let arr = got.as_array()
                    .unwrap_or_else(|| panic!("[{}] expected array", case.name));
                assert_eq!(arr.len(), *n, "[{}] count mismatch", case.name);
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

        let results = collect_results(
            &format!("SELECT {}('$.person.name', data::text) FROM test_json WHERE id = 1", EXT_NAME)
        );
        let got: serde_json::Value = serde_json::from_str(&results[0]).unwrap();
        let want: serde_json::Value = serde_json::from_str(r#"["John"]"#).unwrap();
        assert_eq!(got, want);
    }

    #[pg_test]
    fn test_correctness_large() {
        let large = load_large_json();
        for query in &["$..name", "$..city", "$..id"] {
            let sql = build_sql(query, &large);
            let results = collect_results(&sql);
            assert!(!results.is_empty(), "[large {}] got no results", query);
            let got: serde_json::Value = serde_json::from_str(&results[0])
                .unwrap_or_else(|e| panic!("[large {}] bad JSON: {}", query, e));
            let arr = got.as_array()
                .unwrap_or_else(|| panic!("[large {}] expected array", query));
            assert!(!arr.is_empty(), "[large {}] empty result array", query);
        }
    }

    const RSONPATH_STR: &str = "rsonpath_ext_table_iter_str";
    const RSONPATH_JSON: &str = "rsonpath_ext_table_iter_json";
    // #[pg_test]
    // fn test_correctness_large2(ext_name: &str) {
    //     let large = load_large_json();
    //     for test_case in TEST_CASES_LARGE {
    //         let query = test_case.query;
    //         let name = test_case.name;
    //         let sql = build_sql2(ext_name, query, &large);
    //         let results = collect_results(&sql);
    //         assert!(!results.is_empty(), "[large {}] got no results", query);
    //         let got: serde_json::Value = serde_json::from_str(&results[0])
    //             .unwrap_or_else(|e| panic!("[large {}] bad JSON: {}", query, e));
    //         let arr = got.as_array()
    //             .unwrap_or_else(|| panic!("[large {}] expected array", query));
    //         assert!(!arr.is_empty(), "[large {}] empty result array", query);
    //     }
    // }
    // == Performance ==

    fn bench(sql: &str, warmup: usize, iters: usize) -> f64 {
        for _ in 0..warmup {
            let _ = collect_results(sql);
        }
        let start = Instant::now();
        for _ in 0..iters {
            let _ = collect_results(sql);
        }
        start.elapsed().as_secs_f64() * 1000.0 / iters as f64
    }


    fn bench2(sql: &str, warmup: usize, iters: usize) -> f64 {
        for _ in 0..warmup {
            run_qeury_discard_results(sql);
        }
        let start = Instant::now();
        for _ in 0..iters {
            run_qeury_discard_results(sql);
        }
        start.elapsed().as_secs_f64() * 1000.0 / iters as f64
    }


    #[pg_test]
    fn test_performance_large() {
        Spi::run("SET client_min_messages = WARNING;").unwrap();
        let mut report = String::new();
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        writeln!(report, "# perf results (epoch: {})", timestamp).unwrap();
        writeln!(report, "{:<35} {:>12} {:>10} {:>12}",
            "Test", "JSON bytes", "Iters", "Avg (ms)").unwrap();
        writeln!(report, "{}", "-".repeat(73)).unwrap();

        let large = load_large_json();
        let large_bytes = large.len();

        for test_case in TEST_CASES_LARGE {
            let query = test_case.query;
            let name = test_case.name;
            let sql = build_sql2(RSONPATH_STR, query, &large);
            let iters = 5;
            let avg_ms = bench2(&sql, 1, iters);
            writeln!(report, "{:<35} {:>12} {:>10} {:>12.4}",
                format!("{}:{}", RSONPATH_STR, name), large_bytes, iters, avg_ms).unwrap();
        }

        for test_case in TEST_CASES_LARGE {
            let query = test_case.query;
            let name = test_case.name;
            let sql = build_sql2(RSONPATH_JSON, query, &large);
            let iters = 5;
            let avg_ms = bench2(&sql, 1, iters);
            writeln!(report, "{:<35} {:>12} {:>10} {:>12.4}",
                format!("{}:{}", RSONPATH_JSON, name), large_bytes, iters, avg_ms).unwrap();
        }

        std::fs::write(PERF_RESULTS_PATH, &report).unwrap_or_else(|e| {
            panic!("Failed to write perf results to {}: {}", PERF_RESULTS_PATH, e)
        });
    }

    #[pg_test]
    fn test_performance() {
        let mut report = String::new();
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        writeln!(report, "# perf results (epoch: {})", timestamp).unwrap();
        writeln!(report, "{:<35} {:>12} {:>10} {:>12}",
            "Test", "JSON bytes", "Iters", "Avg (ms)").unwrap();
        writeln!(report, "{}", "-".repeat(73)).unwrap();

        for case in TEST_CASES {
            let sql = build_sql(case.query, case.json);
            let json_bytes = case.json.len();
            let iters = 100;
            let avg_ms = bench(&sql, 5, iters);
            writeln!(report, "{:<35} {:>12} {:>10} {:>12.4}",
                case.name, json_bytes, iters, avg_ms).unwrap();
        }

        let large = load_large_json();
        let large_bytes = large.len();
        for (name, query) in &[
            ("large_all_names", "$..name"),
            ("large_all_cities", "$..city"),
            ("large_all_ids", "$..id"),
        ] {
            let sql = build_sql(query, &large);
            let iters = 5;
            let avg_ms = bench(&sql, 1, iters);
            writeln!(report, "{:<35} {:>12} {:>10} {:>12.4}",
                name, large_bytes, iters, avg_ms).unwrap();
        }

        std::fs::write(PERF_RESULTS_PATH, &report).unwrap_or_else(|e| {
            panic!("Failed to write perf results to {}: {}", PERF_RESULTS_PATH, e)
        });
    }
}

#[cfg(test)]
pub mod pg_test {
    pub fn setup(_options: Vec<&str>) {}

    #[must_use]
    pub fn postgresql_conf_options() -> Vec<&'static str> {
        vec![]
    }
}

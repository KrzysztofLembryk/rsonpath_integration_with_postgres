use pgrx::prelude::*;

::pgrx::pg_module_magic!(name, version);

use std::fmt::Display;
use rsonpath::input::BorrowedBytes;
use rsonpath::{
    engine::{Compiler, Engine, RsonpathEngine},
    input::MmapInput,
    result::{MatchWriter, Sink, Match},
    
};


pub struct SinkVec<D>
{
    pub data: Vec<D>,
}

impl<D> SinkVec<D> {
    pub fn new() -> SinkVec<D> {
        SinkVec {
            data: vec![],
        }
    }
}


impl<D> Sink<D> for SinkVec<D>
where
    D: Display,
{
    type Error = std::convert::Infallible;

    #[inline(always)]
    fn add_match(&mut self, data: D) -> Result<(), Self::Error> {
        self.data.push(data);
        Ok(())
    }
}


#[pg_extern]
fn rsonpath_ext(query: &str, json_str: &str) -> String 
{
    // TODO: add handling errors correctly
    let query = rsonpath_syntax
        ::parse(query)
            .expect("got query parse error");
    let input = BorrowedBytes::new(json_str.as_bytes());
    let engine = RsonpathEngine::compile_query(&query)
        .expect("engine compile err");
    let mut sink_vec = SinkVec::new();

    engine.matches(&input, &mut sink_vec)
        .expect("Engine count error");

    // let mut res = vec![];

    // for val in &sink_vec.data
    // {
    //     res.push(String::from_utf8_lossy(val.bytes()));
    // }

    let values: Vec<serde_json::Value> = sink_vec.data.iter()
        .map(|val| serde_json::from_slice(val.bytes()).unwrap())
        .collect();

    // return as a pretty-printed JSON array
    return serde_json::to_string_pretty(&values).unwrap();

    // return format!("rsonpath_postgres_ext, engine.count result: {:?}", res);
}


#[cfg(any(test, feature = "pg_test"))]
#[pg_schema]
mod tests {
    use pgrx::prelude::*;

    #[pg_test]
    fn test_hello_rsonpath_postgres_ext() {
        assert_eq!("Hello, rsonpath_postgres_ext", &crate::rsonpath_ext("", ""));
    }

}

/// This module is required by `cargo pgrx test` invocations.
/// It must be visible at the root of your extension crate.
#[cfg(test)]
pub mod pg_test {
    pub fn setup(_options: Vec<&str>) {
        // perform one-off initialization when the pg_test framework starts
    }

    #[must_use]
    pub fn postgresql_conf_options() -> Vec<&'static str> {
        // return any postgresql.conf settings that are required for your tests
        vec![]
    }
}

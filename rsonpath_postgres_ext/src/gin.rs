use pgrx::prelude::*;
use pgrx::{pg_sys, Internal};
use rsonpath::input::BorrowedBytes;
use rsonpath::engine::{Compiler, Engine, RsonpathEngine};

/// The user-visible operator: `jsonb @@@ text`.
/// Returns true if the rsonpath query has at least one match in the document.
#[pg_extern(immutable, parallel_safe)]
fn rsonpath_jsonb_match(doc: pgrx::JsonB, query: &str) -> bool {
    let doc_text = serde_json::to_string(&doc.0).expect("serialize doc");
    let parsed = rsonpath_syntax::parse(query).expect("parse rsonpath");
    let input = BorrowedBytes::new(doc_text.as_bytes());
    let engine = RsonpathEngine::compile_query(&parsed).expect("compile rsonpath");
    engine.count(&input).expect("count") > 0
}

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_gin_extract_value(
    item: pgrx::JsonB,
    nkeys: Internal,
    _null_flags: Internal,
) -> Internal {
    // pgrx::info!("[GIN] extractValue called");

    let keys = collect_object_keys(&item.0);

    unsafe {
        let nkeys_ptr = nkeys.unwrap().unwrap().cast_mut_ptr::<i32>();
        *nkeys_ptr = keys.len() as i32;
    }

    unsafe { palloc_datum_array(&keys) }
}

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_gin_extract_query(
    query: &str,
    nkeys: Internal,
    _strategy: i16,
    _pmatch: Internal,
    _extra_data: Internal,
    _null_flags: Internal,
    search_mode: Internal,
) -> Internal {
    // pgrx::info!("[GIN] extractQuery called: {}", query);

    let keys = jsonpath_required_keys(query);

    unsafe {
        let nkeys_ptr = nkeys.unwrap().unwrap().cast_mut_ptr::<i32>();
        *nkeys_ptr = keys.len() as i32;

        let mode_ptr = search_mode.unwrap().unwrap().cast_mut_ptr::<i32>();
        if keys.is_empty() {
            *mode_ptr = pg_sys::GIN_SEARCH_MODE_ALL as i32;
        } else {
            *mode_ptr = pg_sys::GIN_SEARCH_MODE_DEFAULT as i32;
        }
    }

    unsafe { palloc_datum_array(&keys) }
}

#[pg_extern(immutable, parallel_safe)]
fn rsonpath_gin_consistent(
    check: Internal,
    _strategy: i16,
    _query: &str,
    nkeys: i32,
    _extra_data: Internal,
    recheck: Internal,
    _query_keys: Internal,
    _null_flags: Internal,
) -> bool {
    // pgrx::info!("[GIN] consistent called (nkeys={})", nkeys);

    unsafe {
        let recheck_ptr = recheck.unwrap().unwrap().cast_mut_ptr::<bool>();
        *recheck_ptr = true;

        let check_ptr = check.unwrap().unwrap().cast_mut_ptr::<bool>();
        for i in 0..nkeys as isize {
            if !*check_ptr.offset(i) {
                return false;
            }
        }
    }

    true
}

fn jsonpath_required_keys(query: &str) -> Vec<String> {
    let Ok(parsed) = rsonpath_syntax::parse(query) else {
        return Vec::new();
    };

    let mut keys = Vec::new();
    for seg in parsed.segments() {
        for selector in seg.selectors().iter() {
            if let rsonpath_syntax::Selector::Name(name) = selector {
                keys.push(name.unquoted().to_string());
            }
        }
    }
    keys.sort();
    keys.dedup();
    keys
}

fn collect_object_keys(v: &serde_json::Value) -> Vec<String> {
    let mut keys = Vec::new();
    walk(v, &mut keys);
    keys.sort();
    keys.dedup();
    keys
}

fn walk(v: &serde_json::Value, out: &mut Vec<String>) {
    match v {
        serde_json::Value::Object(m) => {
            for (k, child) in m {
                out.push(k.clone());
                walk(child, out);
            }
        }
        serde_json::Value::Array(a) => {
            for child in a {
                walk(child, out);
            }
        }
        _ => {}
    }
}

unsafe fn palloc_datum_array(keys: &[String]) -> Internal {
    let n = keys.len().max(1);
    let bytes = n * std::mem::size_of::<pg_sys::Datum>();
    let array_ptr = pg_sys::palloc(bytes) as *mut pg_sys::Datum;

    for (i, s) in keys.iter().enumerate() {
        *array_ptr.add(i) = string_to_text_datum(s);
    }

    Internal::from(Some(pg_sys::Datum::from(array_ptr)))
}

fn string_to_text_datum(s: &str) -> pg_sys::Datum {
    unsafe {
        let cstring = std::ffi::CString::new(s).expect("nul in key");
        let text_ptr = pg_sys::cstring_to_text(cstring.as_ptr());
        pg_sys::Datum::from(text_ptr)
    }
}

extension_sql!(
    r#"
CREATE OPERATOR @@@ (
    LEFTARG = jsonb,
    RIGHTARG = text,
    PROCEDURE = rsonpath_jsonb_match
);

CREATE OPERATOR CLASS rsonpath_jsonb_ops
    FOR TYPE jsonb USING gin AS
        OPERATOR 1 @@@ (jsonb, text),
        FUNCTION 1 bttextcmp(text, text),
        FUNCTION 2 rsonpath_gin_extract_value(jsonb, internal, internal),
        FUNCTION 3 rsonpath_gin_extract_query(text, internal, smallint, internal, internal, internal, internal),
        FUNCTION 4 rsonpath_gin_consistent(internal, smallint, text, integer, internal, internal, internal, internal),
        STORAGE text;
"#,
    name = "rsonpath_gin_opclass",
    requires = [
        rsonpath_jsonb_match,
        rsonpath_gin_extract_value,
        rsonpath_gin_extract_query,
        rsonpath_gin_consistent,
    ],
);

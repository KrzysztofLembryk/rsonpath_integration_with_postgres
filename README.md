# rsonpath integration with Postgres repo

- rsonpath repo: https://github.com/rsonquery/rsonpath
    - for cli use: ```cargo install rsonpath```
    - for usage as crate in .rs files add to Cargo.toml: 
    ```
        rsonpath-lib = "0.10.0"
        rsonpath-syntax = "0.4.1"
    ```
- how to install pgrx, repo: https://github.com/pgcentralfoundation/pgrx?tab=readme-ov-file#system-requirements
- useful articles about pgrx: https://github.com/pgcentralfoundation/pgrx/blob/develop/articles/README.md

# How to
- run pgx

```bash
cargo pgrx run
```

- extension commands 
    - list extensions ```\dx``` or ```SELECT * FROM pg_extension;```
    - remove extension: ```DROP EXTENSION IF EXISTS my_extension;```
```sql
-- remember that it needs to have exact same name
my_extension=# CREATE EXTENSION my_extension;

-- remove

-- use
SELECT new_extension('arg1', 2, 'arg3');
```

# About JSON in postgres
- json datatype: https://www.postgresql.org/docs/current/datatype-json.html
- json funcs: https://www.postgresql.org/docs/9.3/functions-json.html

# Integration

- json table: 
```sql
CREATE TABLE json_table (
    id SERIAL PRIMARY KEY,
    data JSON
);
```

- copying to json table 
```sql
COPY json_table(data) FROM '/tmp/file.json';
```

- example to put in a file:
```json
{"person":{"name":"John","surname":"Doe","phoneNumbers":[{"type":"Home","number":"111-222-333"},{"type":"Work","number":"123-456-789"}]}}
```

# rsonpath_ext 
```bash
SELECT rsonpath_ext_json('$.person.phoneNumbers[*].number', data::text)
FROM json_table;
```

- inline exmpl: ```SELECT rsonpath_ext('$..hobbies[*]', '{"name": "Alice", "age": 30, "hobbies": ["reading", "cycling", "cooking"]}');```

# rsonpath_ext_with_table_iter

```sql
-- str version
SELECT ext.idx, ext.val
FROM json_table, 
     rsonpath_ext_table_iter_str('$.person.phoneNumbers[*]', data::text) AS ext;

-- json version
SELECT ext.idx, ext.val
FROM json_table, 
     rsonpath_ext_table_iter_json('$.person.phoneNumbers[*]', data::text) AS ext;

-- json version with json syntax usage to get value for given key
SELECT ext.val->> 'type' as phone
FROM json_table, 
     rsonpath_ext_table_iter_json('$.person.phoneNumbers[*]', data::text) AS ext;

-- jsonB version
SELECT ext.idx, ext.val
FROM json_table, 
     rsonpath_ext_table_iter_jsonb('$.person.phoneNumbers[*]', data::text) AS ext;
```

# BENCHMARK
- in postgres json field max 1 GB, jsonb max 200MB

# Recompiling postgres so that it doesn't have debug symbols

```bash
cd ~/.pgrx/13.23
make clean
./configure --prefix=$HOME/.pgrx/13.23/pgrx-install --with-pgport=28813
make -j$(nproc)
make install
```
- afterwards command ```SHOW debug_assertions;``` should return off


# how to run tests from cmd in pgrx
- for example: ```cargo pgrx test pg16 --release -- test_performance_large_no_toast```

# using perf
- run ```cargo pgrx run --release ```
- then inside postgres ```SELECT pg_backend_pid();```
- then in other terminal: ```sudo perf record -p PID -g --call-graph dwarf -F 99```
- after postgres query ends issue ctrl+c command in perf terminal 
- to see report: ```sudo perf report```
- to create flamegrapg: ```sudo perf script | ./FlameGraph/stackcollapse-perf.pl | ./FlameGraph/flamegraph.pl > perf_flamegraph.svg```
- to download flamegraph scripts: ```git clone https://github.com/brendangregg/FlameGraph.git```

# Making custom index

- we can create our own operators: https://github.com/pgcentralfoundation/pgrx/blob/b2be3e1822b2e5769ba6253c828674d4c885ff01/pgrx-examples/operators/README.md

## Simpler way, but restricted
- to impl index we would need a boolean function that checks if in given row, there
is at least one match for query

```rust
fn check_if_subjson_exists(json_str: &str, query: &str)
{
    let query = rsonpath_syntax::parse(query).expect("query parse error");
    let input = BorrowedBytes::new(json_str.as_bytes());
    let engine = RsonpathEngine::compile_query(&query).expect("engine compile error");

    return engine.count(&input).expect("engine count error") as i64 > 0
}

// approach wit #[pg_operator(immutable, parallel_safe)] doesnt work since somewhow
// immutability IS NOT propagated to our operator @@

#[pg_extern(immutable, parallel_safe, strict)] 
#[opname(@@)] // operator symbol in SQL
fn rsonpath_contains(json_str: &str, query: &str) -> bool {
    // We pass whole json from row, then we check if at there is at least one sub-json 
    // that satisfies query. 
    // We Return true if there is.
    // Currently we would need to use count to accomplish this.
    // But to make it more optimal, we would need a function that stops once it finds
    // first match
    return check_if_subjson_exists(json_str, query);
}
```
- DOESNT WORK with pg_operator: thanks to operator we can convienientyl write: ```SELECT * FROM bench_json WHERE data::text @@ '$.records[*].name';```
- instead we should call function manually: ```SELECT * FROM bench_json WHERE rsonpath_contains(data::text, '$.records[*].name');```

- so now we can create and index for given query
```sql
CREATE INDEX idx_rsonpath_hobby ON bench_json ( rsonpath_contains(data::text, '$.hobby[*]') );

SELECT * FROM bench_json WHERE rsonpath_contains(data::text, '$.hobby[*]') = true;
```

- in this approach we need a new index for every unique JSON query


- results for dblp ```$.authors[*].name```
```
Without index:
    query_name     |       method       | match_count |  avg_ms   
--------------------+--------------------+-------------+-----------
 array_author_names | rsonpath_ext_count |    18784025 | 51410.865
 array_author_names | rsonpath_ext_str   |    18784025 | 72658.618

With index:
     query_name     |       method       | match_count |  avg_ms   
--------------------+--------------------+-------------+-----------
 array_author_names | rsonpath_ext_count |    18784025 | 84514.835
 array_author_names | rsonpath_ext_str   |    18784025 | 95880.194
```
- Bad example, every row in the dblp dataset contains an author name ($.authors[*].name), the index is slowing us down, because of the cost of scanning B-Tree and random disk access (jumping to the read ID from B-tree on the disc) - **Random I/O**
- Without index we have just a sequential scan, that starts at the beginnning and goes till the end

- Results for our randomly generated data, with only 10% of rows having hobby keys
```
BENCHMARK RESULTS ($.hobby[*])
Time without index: 41047.190 ms (Matches found: 2398501)
Time with index: 40486.211 ms (Matches found: 2398501)
Saved Time: 1.37 % reduction in execution time
Multiplier: 1.01x faster
```


## Complex GIN way, but flexible
 
- To support querying any arbitrary JSON query, we need a Generalized Inverted Index (GIN): https://www.postgresql.org/docs/current/gin.html. 

- GIN operator classes include i.e. ```jsonb_ops```

- GIN breaks a document down into "keys" and stores a mapping of Key -> List of Row IDs.

- functions we need to implement:
    - ```Datum *extractValue(Datum itemValue, int32 *nkeys, bool **nullFlags)```- Takes a raw document (json_str) and breaks it into indexable keys
    ```
        Example: {"user": "John", "age": 30} -> ["user", "age"]
    ```
    - ```Datum *extractQuery(Datum query, int32 *nkeys, StrategyNumber n, bool **pmatch, Pointer **extra_data, bool **nullFlags, int32 *searchMode)``` - Takes the operator query (query) and breaks it into the keys required to satisfy it
    ```
        Example: "$.user.name" -> ["user", "name"]
    ```
    - ```bool consistent(bool check[], StrategyNumber n, Datum query, int32 nkeys, Pointer extra_data[], bool *recheck, Datum queryKeys[], bool nullFlags[])``` - A boolean function that decides if the document truly matches based on the found keys.

- In addition, GIN must have a way to sort the key values stored in the index. The operator class can define the sort ordering by specifying a comparison method:
    - ```int compare(Datum a, Datum b)``` - Compares two keys (not indexed items!) and returns an integer less than zero, zero, or greater than zero, indicating whether the first key is less than, equal to, or greater than the second. Null keys are never passed to this function.

- we can use custom sql in pgrx: https://github.com/pgcentralfoundation/pgrx/blob/b2be3e1822b2e5769ba6253c828674d4c885ff01/pgrx-examples/custom_sql/src/lib.rs

- once we have all of these functions we must define operator class in SQL with these functions:
```rust
extension_sql!(
    r#"
    --  Operator Class that ties the @@ operator to the GIN methods
    CREATE OPERATOR CLASS rsonpath_gin_ops
    DEFAULT FOR TYPE text USING gin AS
        OPERATOR 1 @@ (text, text),
        FUNCTION 1 rsonpath_gin_compare(...),
        FUNCTION 2 rsonpath_gin_extract_value(...),
        FUNCTION 3 rsonpath_gin_extract_query(...),
        FUNCTION 4 rsonpath_gin_consistent(...);
    "#,
    name = "create_rsonpath_gin_opclass",
);
```

- creating index
```sql
CREATE INDEX idx_rsonpath_gin ON bench_json USING gin ( (data::text) rsonpath_gin_ops );
```

- A lot of unsafe code needed to implement, a lot of pointer handlings with ```pgrx::pg_sys``` since Postgres hands us **RAW MEMORY POINTERS**, it expects us 
to:
    - Allocate memory using Postgres's own C memory allocator (palloc). 
    - Write the total count of keys found directly into a provided C integer pointer (*nkeys).
    - Return a raw C-array of Datum structures 

# Gin index impl
Based on code in rsonpath repo - some initial code generated by gemini

```rust
use rsonpath::engine::error::EngineError as RsonpathEngineError;
use rsonpath::classification::{
    simd::{self, config_simd, dispatch_simd, Simd, SimdConfiguration},
    structural::{Structural, StructuralIterator},
};
use rsonpath::result::empty::EmptyRecorder;
use rsonpath::BLOCK_SIZE;
use rsonpath::input::error::InputErrorConvertible;

struct KeyExtractor<'i, I, V> {
    input: &'i I,
    simd: V,
    path_stack: Vec<String>,
    extracted_paths: Vec<String>,
}

pub fn extract_all_keys<I: Input>(input: &I) -> Result<Vec<String>, RsonpathEngineError> {
    let simd_config = simd::configure();
    
    config_simd!(simd_config => |simd| {
        let mut extractor = KeyExtractor::new(input, simd);
        extractor.run()?;
        Ok(extractor.extracted_keys)
    })
}

impl<'i, I, V> KeyExtractor<'i, I, V>
where
    I: Input,
    V: Simd,
{
    fn new(input: &'i I, simd: V) -> Self {
        Self {
            input,
            simd,
            extracted_keys: Vec::new(),
        }
    }

    fn run(&mut self) -> Result<(), RsonpathEngineError> {
        let iter = self.input.iter_blocks(&EmptyRecorder);
        let quote_classifier = self.simd.classify_quoted_sequences(iter);
        let structural_classifier = self.simd.classify_structural_characters(quote_classifier);
        let mut classifier = structural_classifier;
        
        // colons to detect property names
        classifier.turn_colons_on(0);

        dispatch_simd!(self.simd; self, classifier =>
        fn<'i, I, V>(
            eng: &mut KeyExtractor<'i, I, V>,
            classifier: &mut <V as Simd>::StructuralClassifier<'i, <I as Input>::BlockIterator<'i, 'static, EmptyRecorder, BLOCK_SIZE>>
        ) -> Result<(), RsonpathEngineError>
        where
            I: Input,
            V: Simd
        {
            loop {
                let mut next_event = match classifier.next() {
                    Ok(e) => e,
                    Err(err) => return Err(err.into()),
                };
                
                if let Some(event) = next_event.take() {
                    match event {
                        Structural::Colon(idx) => {
                            let key = eng.extract_key_at_colon(idx)?;
                            
                            // Combine the stack with the new key to get the full path
                            let full_path = if eng.path_stack.is_empty() {
                                key.clone()
                            } else {
                                format!("{}.{}", eng.path_stack.join("."), key)
                            };
                            
                            eng.extracted_paths.push(full_path);
                            
                            // Push the key onto the stack until we hit the matching '}'
                            eng.path_stack.push(key);
                        },
                        Structural::Opening(BracketType::Curly, _) => {
                            // A new object started, our stack is already prepared by the Colon handler
                        },
                        Structural::Closing(BracketType::Curly, _) => {
                            // An object ended, pop the last key off the path stack
                            eng.path_stack.pop();
                        },
                        Structural::Opening(BracketType::Square, _) => {
                            // Array opened, maybe push an "[*]" token to the stack
                            eng.path_stack.push("[*]".to_string());
                        },
                        Structural::Closing(BracketType::Square, _) => {
                            // Array closed, pop the "[*]" token
                            eng.path_stack.pop();
                        },
                        _ => {}
                    }
            }
                } else {
                    break;
                }
            }

            Ok(())
        })
    }

    #[inline(always)]
    fn handle_colon(&mut self, idx: usize) -> Result<(), RsonpathEngineError> {
        // Scanning backwards to find the property name before the colon
        let closing_quote_idx = match self.input.seek_backward(idx - 1, b'"') {
            Some(x) => x,
            None => {
                return Err(RsonpathEngineError::MalformedStringQuotes(idx - 1));
            }
        };

        let opening_quote_idx = match self.input.seek_backward(closing_quote_idx - 1, b'"') {
            Some(x) => x,
            None => {
                return Err(RsonpathEngineError::MalformedStringQuotes(closing_quote_idx - 1));
            }
        };

        // Extract the raw bytes of the key
        let key_bytes = self.input.slice(opening_quote_idx + 1, closing_quote_idx);
        
        // Push the key representation (converting safely if the array is assumed UTF-8)
        let key_string = String::from_utf8_lossy(key_bytes).into_owned();
        self.extracted_keys.push(key_string);

        Ok(())
    }
}
```
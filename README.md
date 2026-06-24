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

# How to run pgrx

```bash
cargo pgrx run --release
```

## Recompiling postgres so that it doesn't have debug symbols

```bash
cd ~/.pgrx/13.23
make clean
./configure --prefix=$HOME/.pgrx/13.23/pgrx-install --with-pgport=28813
make -j$(nproc)
make install
```
- afterwards command ```SHOW debug_assertions;``` should return off

# How to handle postgres extensions
- extension commands 
    - list extensions ```\dx``` or ```SELECT * FROM pg_extension;```
```sql
-- remember that it needs to have exact same name
my_extension= CREATE EXTENSION my_extension;

-- remove
DROP EXTENSION IF EXISTS my_extension;

-- use
SELECT my_extension('arg1', 2, 'arg3');
```

## About JSON in postgres
- json datatype: https://www.postgresql.org/docs/current/datatype-json.html
- json funcs: https://www.postgresql.org/docs/9.3/functions-json.html

## Simple json examples in postgres

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

# Rsonpath - how to use it in postgres step-by-step
- simple example with creating table
```bash
# run pgrx
cargo pgrx run --release

# create our extension functions in postgres
rsonpath_postgres_ext=# CREATE EXTENSION rsonpath_postgres_ext;
```

```sql
-- create simple table with json column
CREATE TABLE json_table (
    id SERIAL PRIMARY KEY,
    data JSON
);
-- populate it with simple json
INSERT INTO json_table (data)
VALUES ($$
{"person":{"name":"John","surname":"Doe","phoneNumbers":[{"type":"Home","number":"111-222-333"},{"type":"Work","number":"123-456-789"}]}}
$$::json);

-- run one of our extensions
SELECT rsonpath_ext_json('$.person.phoneNumbers[*].number', data::text)
FROM json_table;
```

- simple inline example
```sql
SELECT rsonpath_ext('$..hobbies[*]', '{"name": "Alice", "age": 30, "hobbies": ["reading", "cycling", "cooking"]}');
```

# BENCHMARKING
- in postgres json field max 1 GB, jsonb max 200MB (when casting json to jsonb we could maximally cast 90MB json)

- our sql benchmark scripts are in ```./sql_scripts/```

- scripts for generating data are in ```./testdata/```


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

# Making GIN index

- We can create our own operators: https://github.com/pgcentralfoundation/pgrx/blob/b2be3e1822b2e5769ba6253c828674d4c885ff01/pgrx-examples/operators/README.md

- To support querying any arbitrary JSON query, we need a Generalized Inverted Index (GIN): https://www.postgresql.org/docs/current/gin.html. 

- our implementation is in ```gin.rs```


## More about GIN index
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
CREATE INDEX idx_rsonpath_gin ON bench_json USING gin ( data rsonpath_gin_ops );
```
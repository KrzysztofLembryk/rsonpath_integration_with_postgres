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
SELECT rsonpath_ext('$.person.phoneNumbers[*].number', data::text)
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

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

- extension commands - 
```sql
-- remember that it needs to have exact same name
my_extension=# CREATE EXTENSION my_extension;

-- remove

-- use
SELECT new_extension('arg1', 2, 'arg3');
```

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

- how to use this exmpl
```bash
SELECT rsonpath_ext('$.person.phoneNumbers[*].number', data::text)
FROM json_table;
```

- inline exmpl: ```SELECT rsonpath_ext('$..hobbies[*]', '{"name": "Alice", "age": 30, "hobbies": ["reading", "cycling", "cooking"]}');```

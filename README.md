# PostgreSQL + PL/Python + NetworkX

A small demo of running Python graph code inside PostgreSQL.

## Library

Python functions run inside the database server through **PL/Python**
(`plpython3u`), PostgreSQL's built-in procedural language for Python. The
functions use [NetworkX](https://networkx.org/) for the graph computations.

- [PL/Python functions](https://www.postgresql.org/docs/current/plpython-funcs.html): defining Python functions callable from SQL
- [PL/Python documentation](https://www.postgresql.org/docs/17/plpython.html)
- [PL/Python data type mapping](https://www.postgresql.org/docs/17/plpython-data.html)

## Structure and how it works

```text
Dockerfile          PostgreSQL 17 image + PL/Python + NetworkX 3.4.2
compose.yaml        database service, health check, data volume
init.sql            extension, toy schema and data, SQL function declarations
graph_functions.py  Python implementations called by the SQL functions
queries.sql         example queries
checks.sql          assertions; exits nonzero on failure
```

The `toy` schema stores simple undirected graphs in three tables: `graph`,
`vertex` and `edge` (each edge stored once, with the smaller endpoint first).

`init.sql` declares two SQL functions in `LANGUAGE plpython3u`. Each body imports
`graph_functions.py`, which reads the graph's rows through PL/Python's `plpy`
interface, builds a NetworkX graph and returns the result as JSON:

- `toy.graph_metrics(bigint) → jsonb`: vertex/edge counts, components,
  triangles, connectedness, diameter and degree sequence.
- `toy.shortest_path(bigint, bigint, bigint) → jsonb`: the path as a JSON
  array, or SQL NULL when the endpoints are disconnected.

Integers are `bigint` and lists are `jsonb` arrays, matching how MathQL's
PostgreSQL backend represents values. The functions are `STRICT` (a NULL argument
returns NULL without calling Python), read the current table contents on every
call, and raise SQLSTATE `22023` for an unknown graph or vertex.

On first start with an empty data volume, the Docker entrypoint runs `init.sql`.
After changing `init.sql`, recreate the volume (see below). After changing only
`graph_functions.py`, rebuild with `docker compose up --build --wait`; new
database sessions load the new code.

PL/Python is an untrusted language, so installing it and creating its functions
need a superuser. The credentials here are for local use only.

## Run and test

Requires Docker with Compose v2. Run from this folder; the commands work in
PowerShell. In Git Bash, set `MSYS_NO_PATHCONV=1` first so the `/demo/...` paths
are not rewritten.

Start the database (the first build needs network access to the image registry,
Debian and PyPI):

```sh
docker compose up --build --wait
```

Run the example queries and the checks; the checks end with
`All graph checks passed`:

```sh
docker compose exec -T db psql -U graph_demo -d graph_demo -f /demo/queries.sql
docker compose exec -T db psql -U graph_demo -d graph_demo -f /demo/checks.sql
```

### Try your own queries

Open an interactive `psql` session; end each SQL statement with a semicolon:

```sh
docker compose exec db psql -U graph_demo -d graph_demo
```

```sql
SELECT id, name FROM toy.graph ORDER BY id;
SELECT name, (toy.graph_metrics(id)->>'triangles')::bigint AS triangles
FROM toy.graph ORDER BY triangles DESC, id;
SELECT toy.graph_metrics(1);
SELECT toy.shortest_path(1, 1, 4);                     -- [1, 3, 4]
SELECT toy.shortest_path(2, 1, 4);                     -- NULL: no path
SELECT toy.graph_metrics(999);                         -- error: unknown graph
SELECT (toy.shortest_path(1, 1, 4) ->> 1)::bigint;     -- 3

-- results follow the data; roll back afterwards
BEGIN;
INSERT INTO toy.vertex VALUES (1, 5);
INSERT INTO toy.edge VALUES (1, 4, 5);
SELECT toy.shortest_path(1, 1, 5);                     -- [1, 3, 4, 5]
ROLLBACK;
```

Useful `psql` commands (no semicolon needed): `\dt toy.*` lists the tables,
`\d toy.edge` shows a table's columns and constraints, `\df toy.*` lists the
functions, and `\q` exits (the database keeps running).

To run a single query from your shell:

```sh
docker compose exec -T db psql -U graph_demo -d graph_demo -v ON_ERROR_STOP=1 -c "SELECT toy.shortest_path(1, 1, 4);"
```

Expected metrics for the toy data:

| Graph | Vertices | Edges | Components | Triangles | Diameter |
| --- | ---: | ---: | ---: | ---: | ---: |
| triangle with tail | 4 | 4 | 1 | 1 | 2 |
| two edges and an isolate | 5 | 2 | 3 | 0 | NULL |
| empty graph | 0 | 0 | 0 | 0 | NULL |
| singleton | 1 | 0 | 1 | 0 | 0 |

Host clients can connect to `localhost:55432`, database and user `graph_demo`,
password `graph_demo_local_only`. Change the Compose port if it is already used.

Stop with `docker compose down` (keeps the data). To delete the data and
recreate it from `init.sql`, for example after editing it:

```sh
docker compose down -v
docker compose up --build --wait
```

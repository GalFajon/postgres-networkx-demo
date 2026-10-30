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

The `toy.graph` table stores simple undirected graphs as
[graph6](https://users.cecs.anu.edu.au/~bdm/data/formats.txt) strings, the
encoding MathQL's graph datasets use. Vertices are numbered from 0.

`init.sql` declares two SQL functions in `LANGUAGE plpython3u`. Each body imports
`graph_functions.py`, which decodes the graph6 argument into a NetworkX graph
and returns the result as JSON:

- `toy.graph_metrics(text) → jsonb`: vertex/edge counts, components,
  triangles, connectedness, diameter and degree sequence.
- `toy.shortest_path(text, bigint, bigint) → jsonb`: the path as a JSON
  array, or SQL NULL when the endpoints are disconnected.

The functions take the graph as a value and read no tables, so they are
`IMMUTABLE` and `PARALLEL SAFE`, and work on any graph6 string, not only stored
rows. Integers are `bigint` and lists are `jsonb` arrays, matching how MathQL's
PostgreSQL backend represents values. The functions are `STRICT` (a NULL argument
returns NULL without calling Python) and raise SQLSTATE `22023` for an invalid
graph6 string or a vertex outside the graph.

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
SELECT id, name, graph6 FROM toy.graph ORDER BY id;
SELECT name, (toy.graph_metrics(graph6)->>'triangles')::bigint AS triangles
FROM toy.graph ORDER BY triangles DESC, id;
SELECT toy.graph_metrics('Cx');                        -- triangle with tail
SELECT toy.shortest_path('Cx', 0, 3);                  -- [0, 2, 3]
SELECT toy.shortest_path('D`?', 0, 3);                 -- NULL: no path
SELECT (toy.shortest_path('Cx', 0, 3) ->> 1)::bigint;  -- 2
SELECT toy.graph_metrics('not graph6');                -- error: invalid graph6

-- any graph6 string works, not only stored ones: a 5-cycle
SELECT toy.graph_metrics('Dhc');                       -- diameter 2, no triangles
SELECT toy.shortest_path('Dhc', 0, 2);                 -- [0, 1, 2]
```

Useful `psql` commands (no semicolon needed): `\dt toy.*` lists the tables,
`\d toy.graph` shows a table's columns, `\df toy.*` lists the functions, and
`\q` exits (the database keeps running).

To run a single query from your shell:

```sh
docker compose exec -T db psql -U graph_demo -d graph_demo -v ON_ERROR_STOP=1 -c "SELECT toy.shortest_path('Cx', 0, 3);"
```

Expected metrics for the toy data:

| Graph | graph6 | Vertices | Edges | Components | Triangles | Diameter |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| triangle with tail | `Cx` | 4 | 4 | 1 | 1 | 2 |
| two edges and an isolate | ``D`?`` | 5 | 2 | 3 | 0 | NULL |
| empty graph | `?` | 0 | 0 | 0 | 0 | NULL |
| singleton | `@` | 1 | 0 | 1 | 0 | 0 |

Host clients can connect to `localhost:55432`, database and user `graph_demo`,
password `graph_demo_local_only`. Change the Compose port if it is already used.

Stop with `docker compose down` (keeps the data). To delete the data and
recreate it from `init.sql`, for example after editing it:

```sh
docker compose down -v
docker compose up --build --wait
```

# PostgreSQL + PL/Python + NetworkX

A small demo of running Python graph code inside PostgreSQL.

<<<<<<< HEAD
See the official [PL/Python function documentation](https://www.postgresql.org/docs/current/plpython-funcs.html) for how to define Python functions callable from SQL.

PostgreSQL stores simple undirected graphs in three tables: `toy.graph`,
`toy.vertex`, and `toy.edge`. Two SQL-callable Python functions load those rows
through PostgreSQL's `plpy` SPI interface and run NetworkX **inside the database
server**:

- `toy.graph_metrics(bigint) → jsonb`: vertex/edge counts, connected components,
  triangles, connectedness, diameter and descending degree sequence.
- `toy.shortest_path(bigint, bigint, bigint) → jsonb`: a shortest path as a JSON array,
  or SQL NULL when the endpoints are disconnected.
=======
## Library

Python functions run inside the database server through **PL/Python**
(`plpython3u`), PostgreSQL's built-in procedural language for Python. The
functions use [NetworkX](https://networkx.org/) for the graph computations.

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
>>>>>>> 1ffafa6 (Restructure the README into library, structure and running)

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

Start the database (the first build needs network access):

```sh
docker compose up --build --wait
```

<<<<<<< HEAD
This builds the image and waits for PostgreSQL readiness. Image building needs
network access to the image registry, Debian and PyPI.

### Try your own queries

Open an interactive `psql` command line inside the running database container:

```sh
docker compose exec db psql -U graph_demo -d graph_demo
```

At the `graph_demo=#` prompt, paste SQL and end each statement with a semicolon.
For example, list the graphs and calculate their number of triangles in Python:

```sql
SELECT id, name FROM toy.graph ORDER BY id;

SELECT name,
       (toy.graph_metrics(id)->>'triangles')::bigint AS triangles
FROM toy.graph
ORDER BY triangles DESC, id;
```

The second query returns 1 triangle for `triangle with tail` and 0 for the other
three graphs. Change the SELECT list or add a WHERE clause to explore the data.
You can also call the functions directly:

```sql
SELECT toy.graph_metrics(1);
SELECT toy.shortest_path(1, 1, 4); -- returns [1, 3, 4]
```

Useful `psql` commands (no semicolon needed):

- `\dt toy.*` lists the graph tables.
- `\d toy.edge` shows the edge table's columns and constraints.
- `\df toy.*` lists the example's SQL functions.
- `\q` exits back to your shell; the database keeps running.

To run a single query directly from PowerShell or a POSIX shell:

```sh
docker compose exec -T db psql -U graph_demo -d graph_demo -v ON_ERROR_STOP=1 -c "SELECT toy.shortest_path(1, 1, 4);"
```

### Run the supplied examples and checks

Back in your shell, run:
=======
Run the example queries and the checks; the checks end with
`All graph checks passed`:
>>>>>>> 1ffafa6 (Restructure the README into library, structure and running)

```sh
docker compose exec -T db psql -U graph_demo -d graph_demo -f /demo/queries.sql
docker compose exec -T db psql -U graph_demo -d graph_demo -f /demo/checks.sql
```

<<<<<<< HEAD
`checks.sql` fails with a nonzero exit code on a failed assertion and rolls back
its temporary data change. It covers exact metrics, empty and disconnected
graphs, isolated vertices, singleton diameter, shortest paths, NULL inputs,
invalid IDs and results after an edge change.
=======
To try things by hand, open a session with
`docker compose exec db psql -U graph_demo -d graph_demo`:
>>>>>>> 1ffafa6 (Restructure the README into library, structure and running)

```sql
\df toy.*
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

Expected metrics for the toy data:

| Graph | Vertices | Edges | Components | Triangles | Diameter |
| --- | ---: | ---: | ---: | ---: | ---: |
| triangle with tail | 4 | 4 | 1 | 1 | 2 |
| two edges and an isolate | 5 | 2 | 3 | 0 | NULL |
| empty graph | 0 | 0 | 0 | 0 | NULL |
| singleton | 1 | 0 | 1 | 0 | 0 |

Host clients can connect to `localhost:55432`, database and user `graph_demo`,
password `graph_demo_local_only`.

<<<<<<< HEAD
Host clients can connect to `localhost:55432`, database/user `graph_demo`,
password `graph_demo_local_only`. Change the Compose port if it is already used.
The port binds only to localhost. These credentials and the superuser account
are for this local example.

## Files and lifecycle

- `Dockerfile`: installs the extension and NetworkX in the server image.
- `compose.yaml`: database service, health check and persistent named volume.
- `init.sql`: extension, schema, toy data and Python function declarations.
- `graph_functions.py`: Python implementations, imported by the SQL functions.
- `queries.sql`: example SELECT queries.
- `checks.sql`: executable database assertions.

SQL arrays map to Python lists; JSONB results are explicitly serialized with
`json.dumps`. Both functions are `STABLE` because they read tables and are
`PARALLEL UNSAFE`. They rebuild the graph for each call, suitable for toy data;
bulk graph analytics would need a separate performance design. Edge constraints
reject loops, duplicate/reversed edges and nonexistent endpoints.

The Docker entrypoint runs `init.sql` only on the first initialization of an
empty data volume. `docker compose down` stops the project and preserves data.
After changing the initialization SQL, use the following **only if you want to
delete this example's database and recreate the toy data**:
=======
Stop with `docker compose down` (keeps the data). To delete the data and
recreate it from `init.sql`, for example after editing it:
>>>>>>> 1ffafa6 (Restructure the README into library, structure and running)

```sh
docker compose down -v
docker compose up --build --wait
```
<<<<<<< HEAD

After changing only the Python module, rebuild/recreate with
`docker compose up --build --wait`; new backend sessions import the new code.

PL/Python is an untrusted language with server-process privileges; extension
installation and function creation require a PostgreSQL superuser. Ordinary
callers can execute functions when granted the appropriate SQL privileges.
See the official [PL/Python documentation](https://www.postgresql.org/docs/17/plpython.html)
and [data mapping documentation](https://www.postgresql.org/docs/17/plpython-data.html).

## Validation status

Verified on 2026-10-30 with Docker's Linux engine: PostgreSQL 17.11
(`17.11-1.pgdg12+2`, x86_64), embedded Python 3.11.2, and NetworkX 3.4.2.
`docker compose up --build --wait` built the image, initialized the toy database
and reported a healthy service. Both `queries.sql` and `checks.sql` completed
with exit code 0; the checks reported `All graph checks passed`. The queries
returned the metrics above, path `[1, 3, 4]`, and SQL NULL for disconnected
endpoints. Compose configuration and Python syntax were also validated.
=======
>>>>>>> 1ffafa6 (Restructure the README into library, structure and running)

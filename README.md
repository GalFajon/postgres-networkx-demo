# PostgreSQL + PL/Python + NetworkX

A standalone example of PostgreSQL's `plpython3u` extension using NetworkX for graph analytics inside the database. It needs no external dataset or host Python installation.

PostgreSQL stores simple undirected graphs in three tables: `toy.graph`,
`toy.vertex`, and `toy.edge`. Two SQL-callable Python functions load those rows
through PostgreSQL's `plpy` SPI interface and run NetworkX **inside the database
server**:

- `toy.graph_metrics(integer) → jsonb`: vertex/edge counts, connected components,
  triangles, connectedness, diameter and descending degree sequence.
- `toy.shortest_path(integer, integer, integer) → integer[]`: a shortest path,
  or SQL NULL when the endpoints are disconnected.

The image uses PostgreSQL 17 on Debian Bookworm, Debian's matching PL/Python
package and Python 3.11, with NetworkX pinned to 3.4.2. The base-image tag and
Debian packages can receive updates; this is not a digest-locked build.

## Run

Install Docker with Compose v2 and start its Linux container engine. Run these
commands from this folder (the commands work in PowerShell and POSIX shells):

```sh
docker compose up --build --wait
```

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
       (toy.graph_metrics(id)->>'triangles')::integer AS triangles
FROM toy.graph
ORDER BY triangles DESC, id;
```

The second query returns 1 triangle for `triangle with tail` and 0 for the other
three graphs. Change the SELECT list or add a WHERE clause to explore the data.
You can also call the functions directly:

```sql
SELECT toy.graph_metrics(1);
SELECT toy.shortest_path(1, 1, 4); -- returns {1,3,4}
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

```sh
docker compose exec -T db psql -U graph_demo -d graph_demo -f /demo/queries.sql
docker compose exec -T db psql -U graph_demo -d graph_demo -f /demo/checks.sql
```

`checks.sql` fails with a nonzero exit code on a failed assertion and rolls back
its temporary data change. It covers exact metrics, empty and disconnected
graphs, isolated vertices, singleton diameter, shortest paths, NULL inputs,
invalid IDs and results after an edge change.

Expected metrics:

| Graph | Vertices | Edges | Components | Triangles | Diameter |
| --- | ---: | ---: | ---: | ---: | ---: |
| triangle with tail | 4 | 4 | 1 | 1 | 2 |
| two edges and an isolate | 5 | 2 | 3 | 0 | NULL |
| empty graph | 0 | 0 | 0 | 0 | NULL |
| singleton | 1 | 0 | 1 | 0 | 0 |

The triangle query returns `triangle with tail`. Its path from 1 to 4 is
`{1,3,4}`. An empty graph is defined here as not connected, with NULL diameter.
Unknown graph IDs or endpoints raise SQLSTATE `22023`; NULL arguments return
SQL NULL without invoking Python (`STRICT`).

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

```sh
docker compose down -v
docker compose up --build --wait
```

After changing only the Python module, rebuild/recreate with
`docker compose up --build --wait`; new backend sessions import the new code.

PL/Python is an untrusted language with server-process privileges; extension
installation and function creation require a PostgreSQL superuser. Ordinary
callers can execute functions when granted the appropriate SQL privileges.
See the official [PL/Python documentation](https://www.postgresql.org/docs/17/plpython.html)
and [data mapping documentation](https://www.postgresql.org/docs/17/plpython-data.html).

## Validation status

Verified on 2026-10-24 with Docker's Linux engine: PostgreSQL 17.11
(`17.11-1.pgdg12+2`, x86_64), embedded Python 3.11.2, and NetworkX 3.4.2.
`docker compose up --build --wait` built the image, initialized the toy database
and reported a healthy service. Both `queries.sql` and `checks.sql` completed
with exit code 0; the checks reported `All graph checks passed`. The queries
returned the metrics above, path `{1,3,4}`, and SQL NULL for disconnected
endpoints. Compose configuration and Python syntax were also validated.

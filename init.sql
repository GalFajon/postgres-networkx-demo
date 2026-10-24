\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION plpython3u;
CREATE SCHEMA toy;

CREATE TABLE toy.graph (
    id integer PRIMARY KEY,
    name text NOT NULL UNIQUE
);
CREATE TABLE toy.vertex (
    graph_id integer REFERENCES toy.graph(id),
    vertex integer,
    PRIMARY KEY (graph_id, vertex)
);
-- Simple undirected graphs: store each edge once, smaller endpoint first.
CREATE TABLE toy.edge (
    graph_id integer NOT NULL,
    source integer NOT NULL,
    target integer NOT NULL,
    PRIMARY KEY (graph_id, source, target),
    FOREIGN KEY (graph_id, source) REFERENCES toy.vertex(graph_id, vertex),
    FOREIGN KEY (graph_id, target) REFERENCES toy.vertex(graph_id, vertex),
    CHECK (source < target)
);

INSERT INTO toy.graph VALUES
    (1, 'triangle with tail'), (2, 'two edges and an isolate'),
    (3, 'empty graph'), (4, 'singleton');
INSERT INTO toy.vertex VALUES
    (1, 1), (1, 2), (1, 3), (1, 4),
    (2, 1), (2, 2), (2, 3), (2, 4), (2, 5), (4, 1);
INSERT INTO toy.edge VALUES
    (1, 1, 2), (1, 1, 3), (1, 2, 3), (1, 3, 4),
    (2, 1, 2), (2, 3, 4);

CREATE FUNCTION toy.graph_metrics(graph_id integer)
RETURNS jsonb
LANGUAGE plpython3u STABLE STRICT PARALLEL UNSAFE
AS $$
from graph_functions import metrics
return metrics(plpy, graph_id)
$$;

CREATE FUNCTION toy.shortest_path(graph_id integer, source integer, target integer)
RETURNS integer[]
LANGUAGE plpython3u STABLE STRICT PARALLEL UNSAFE
AS $$
from graph_functions import shortest_path
return shortest_path(plpy, graph_id, source, target)
$$;
COMMIT;

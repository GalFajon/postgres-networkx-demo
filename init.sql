\set ON_ERROR_STOP on
BEGIN;
CREATE EXTENSION plpython3u;
CREATE SCHEMA toy;

-- Simple undirected graphs in graph6 encoding; vertices are numbered from 0.
CREATE TABLE toy.graph (
    id bigint PRIMARY KEY,
    name text NOT NULL UNIQUE,
    graph6 text NOT NULL
);

INSERT INTO toy.graph VALUES
    (1, 'triangle with tail', 'Cx'),
    (2, 'two edges and an isolate', 'D`?'),
    (3, 'empty graph', '?'),
    (4, 'singleton', '@');

CREATE FUNCTION toy.graph_metrics(graph6 text)
RETURNS jsonb
LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE
AS $$
from graph_functions import metrics
return metrics(plpy, graph6)
$$;

CREATE FUNCTION toy.shortest_path(graph6 text, source bigint, target bigint)
RETURNS jsonb
LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE
AS $$
from graph_functions import shortest_path
return shortest_path(plpy, graph6, source, target)
$$;
COMMIT;

\set ON_ERROR_STOP on
\pset pager off

SELECT g.id, g.name, toy.graph_metrics(g.id) AS metrics
FROM toy.graph AS g ORDER BY g.id;

-- Filter by a value calculated in Python inside the server.
SELECT g.name
FROM toy.graph AS g
WHERE (toy.graph_metrics(g.id)->>'triangles')::integer > 0
ORDER BY g.id;

SELECT toy.shortest_path(1, 1, 4) AS path_1_to_4; -- {1,3,4}
SELECT toy.shortest_path(2, 1, 4) AS disconnected_path; -- SQL NULL

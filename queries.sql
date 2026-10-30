\set ON_ERROR_STOP on
\pset pager off

SELECT g.id, g.name, g.graph6, toy.graph_metrics(g.graph6) AS metrics
FROM toy.graph AS g ORDER BY g.id;

-- Filter by a value calculated in Python inside the server.
SELECT g.name
FROM toy.graph AS g
WHERE (toy.graph_metrics(g.graph6)->>'triangles')::bigint > 0
ORDER BY g.id;

SELECT toy.shortest_path(g.graph6, 0, 3) AS path_0_to_3 -- [0, 2, 3]
FROM toy.graph AS g WHERE g.name = 'triangle with tail';
SELECT toy.shortest_path('D`?', 0, 3) AS disconnected_path; -- SQL NULL

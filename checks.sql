\set ON_ERROR_STOP on
DO $$
BEGIN
    ASSERT toy.graph_metrics('Cx') = '{"vertices":4,"edges":4,"components":1,"triangles":1,"connected":true,"diameter":2,"degree_sequence":[3,2,2,1]}'::jsonb;
    ASSERT toy.graph_metrics('D`?') = '{"vertices":5,"edges":2,"components":3,"triangles":0,"connected":false,"diameter":null,"degree_sequence":[1,1,1,1,0]}'::jsonb;
    ASSERT toy.graph_metrics('?') = '{"vertices":0,"edges":0,"components":0,"triangles":0,"connected":false,"diameter":null,"degree_sequence":[]}'::jsonb;
    ASSERT toy.graph_metrics('@')->>'diameter' = '0';
    ASSERT toy.shortest_path('Cx', 0, 3) = '[0,2,3]'::jsonb;
    ASSERT toy.shortest_path('Cx', 1, 1) = '[1]'::jsonb;
    ASSERT jsonb_typeof(toy.shortest_path('Cx', 0, 3)) = 'array';
    ASSERT toy.shortest_path('D`?', 0, 3) IS NULL;
    ASSERT toy.graph_metrics(NULL) IS NULL;
    ASSERT (SELECT count(*) FROM toy.graph
            WHERE (toy.graph_metrics(graph6)->>'triangles')::bigint > 0) = 1;
    BEGIN
        PERFORM toy.graph_metrics('not graph6');
        RAISE EXCEPTION 'Invalid graph6 should fail';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM toy.shortest_path('Cx', 0, 99);
        RAISE EXCEPTION 'Missing vertex should fail';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
END;
$$;
SELECT 'All graph checks passed' AS result;

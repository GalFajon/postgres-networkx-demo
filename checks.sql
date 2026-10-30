\set ON_ERROR_STOP on
BEGIN;
DO $$
BEGIN
    ASSERT toy.graph_metrics(1) = '{"vertices":4,"edges":4,"components":1,"triangles":1,"connected":true,"diameter":2,"degree_sequence":[3,2,2,1]}'::jsonb;
    ASSERT toy.graph_metrics(2) = '{"vertices":5,"edges":2,"components":3,"triangles":0,"connected":false,"diameter":null,"degree_sequence":[1,1,1,1,0]}'::jsonb;
    ASSERT toy.graph_metrics(3) = '{"vertices":0,"edges":0,"components":0,"triangles":0,"connected":false,"diameter":null,"degree_sequence":[]}'::jsonb;
    ASSERT toy.graph_metrics(4)->>'diameter' = '0';
    ASSERT toy.shortest_path(1, 1, 4) = '[1,3,4]'::jsonb;
    ASSERT toy.shortest_path(1, 2, 2) = '[2]'::jsonb;
    ASSERT jsonb_typeof(toy.shortest_path(1, 1, 4)) = 'array';
    ASSERT toy.shortest_path(2, 1, 4) IS NULL;
    ASSERT toy.graph_metrics(NULL) IS NULL;
    BEGIN
        PERFORM toy.graph_metrics(999);
        RAISE EXCEPTION 'Missing graph should fail';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        PERFORM toy.shortest_path(1, 1, 999);
        RAISE EXCEPTION 'Missing vertex should fail';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
END;
$$;
-- STABLE functions read current database contents, rather than cached graphs.
DELETE FROM toy.edge WHERE graph_id = 1 AND source = 1 AND target = 2;
DO $$ BEGIN
    ASSERT toy.graph_metrics(1)->>'triangles' = '0';
END $$;
ROLLBACK;
SELECT 'All graph checks passed' AS result;

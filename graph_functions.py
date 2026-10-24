"""NetworkX computations executed inside PostgreSQL by PL/Python."""

import json

import networkx as nx


def load_graph(plpy, graph_id):
    # Values are bound through SPI; SQL identifiers are fixed and qualified.
    exists = plpy.prepare("SELECT 1 FROM toy.graph WHERE id = $1", ["integer"])
    if not plpy.execute(exists, [graph_id]):
        plpy.error("Unknown graph id: %s" % graph_id, sqlstate="22023")
    vertices = plpy.prepare(
        "SELECT vertex FROM toy.vertex WHERE graph_id = $1 ORDER BY vertex",
        ["integer"],
    )
    edges = plpy.prepare(
        "SELECT source, target FROM toy.edge WHERE graph_id = $1",
        ["integer"],
    )
    graph = nx.Graph()
    # Adding vertices separately preserves isolated vertices and empty graphs.
    graph.add_nodes_from(row["vertex"] for row in plpy.execute(vertices, [graph_id]))
    graph.add_edges_from(
        (row["source"], row["target"]) for row in plpy.execute(edges, [graph_id])
    )
    return graph


def metrics(plpy, graph_id):
    graph = load_graph(plpy, graph_id)
    connected = len(graph) > 0 and nx.is_connected(graph)
    # JSONB crosses the default PL/Python boundary as JSON text.
    return json.dumps({
        "vertices": graph.number_of_nodes(),
        "edges": graph.number_of_edges(),
        "components": nx.number_connected_components(graph),
        "triangles": sum(nx.triangles(graph).values()) // 3,
        "connected": connected,
        "diameter": nx.diameter(graph) if connected else None,
        "degree_sequence": sorted((d for _, d in graph.degree()), reverse=True),
    })


def shortest_path(plpy, graph_id, source, target):
    graph = load_graph(plpy, graph_id)
    if source not in graph or target not in graph:
        plpy.error("Both endpoints must be vertices of the graph", sqlstate="22023")
    try:
        return nx.shortest_path(graph, source, target)
    except nx.NetworkXNoPath:
        return None

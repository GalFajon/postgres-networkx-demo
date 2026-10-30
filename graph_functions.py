"""NetworkX computations executed inside PostgreSQL by PL/Python."""

import json

import networkx as nx


def parse_graph(plpy, graph6):
    # Functions take the graph as a value and read no tables, so they are IMMUTABLE.
    try:
        return nx.from_graph6_bytes(graph6.encode("ascii"))
    except Exception as e:
        plpy.error("Invalid graph6 string %r: %s" % (graph6, e), sqlstate="22023")


def metrics(plpy, graph6):
    graph = parse_graph(plpy, graph6)
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


def shortest_path(plpy, graph6, source, target):
    graph = parse_graph(plpy, graph6)
    if source not in graph or target not in graph:
        plpy.error("Both endpoints must be vertices of the graph", sqlstate="22023")
    try:
        return json.dumps(nx.shortest_path(graph, source, target))
    except nx.NetworkXNoPath:
        return None

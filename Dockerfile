FROM postgres:17-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-plpython3-17 python3-venv \
    && python3 -m venv /opt/graph-venv \
    && /opt/graph-venv/bin/pip install --no-cache-dir networkx==3.4.2 \
    && rm -rf /var/lib/apt/lists/*

# PL/Python uses Debian's Python, embedded in PostgreSQL. Make the packages
# installed in the venv visible to that interpreter as well.
ENV PYTHONPATH=/opt/graph-venv/lib/python3.11/site-packages:/opt/graph-python
COPY graph_functions.py /opt/graph-python/graph_functions.py
COPY init.sql /docker-entrypoint-initdb.d/01-graphs.sql

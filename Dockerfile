# PaperReady as a container, for hosts that run Docker images (Northflank,
# Google Cloud Run, a VM...). It installs the same system packages as Streamlit
# Community Cloud (packages.txt) and the Python versions pinned in uv.lock.
FROM python:3.12-slim-bookworm

# git: aclpubcheck is installed from its repository. The rest is packages.txt.
COPY packages.txt /tmp/packages.txt
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates $(tr -d '\r' < /tmp/packages.txt) \
    && rm -rf /var/lib/apt/lists/* /tmp/packages.txt

RUN pip install --no-cache-dir "uv>=0.7,<1"
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never UV_PROJECT_ENVIRONMENT=/opt/venv

WORKDIR /app
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --no-install-project --no-cache --python /usr/local/bin/python3

COPY .streamlit .streamlit
COPY assets assets
COPY paperready paperready
COPY views views
COPY streamlit_app.py LICENSE ./

RUN useradd --create-home paperready
USER paperready

# Hosts set PORT (Cloud Run uses 8080); 8501 is Streamlit's default.
ENV PORT=8501 PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
EXPOSE 8501
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.environ[\"PORT\"]}/_stcore/health', timeout=4)"
# exec: Streamlit replaces the shell and gets stop signals directly.
CMD ["sh", "-c", "exec streamlit run streamlit_app.py --server.port=\"$PORT\" --server.address=0.0.0.0 --server.headless=true --browser.gatherUsageStats=false"]

# syntax=docker/dockerfile:1.7
# Dockerfile

# Support both Home Assistant builds and standalone builds
# Only Debian based images are supported (no Alpine)
ARG BUILD_FROM
ARG PYTHON_VERSION=3.13.9

# If BUILD_FROM is set (Home Assistant), use it; otherwise use python-slim
FROM ${BUILD_FROM:-python:${PYTHON_VERSION}-slim}

LABEL \
    io.hass.version="VERSION" \
    io.hass.type="addon" \
    io.hass.arch="aarch64|amd64|armv7" \
    source="https://github.com/Akkudoktor-EOS/EOS"

ENV EOS_DIR="/opt/eos"
# Create persistent data directory similar to home assistant add-on
# - EOS_DATA_DIR: Persistent data directory
# - MPLCONFIGDIR: user customizations to Mathplotlib
ENV EOS_DATA_DIR="/data"
ENV EOS_CACHE_DIR="${EOS_DATA_DIR}/cache"
ENV EOS_OUTPUT_DIR="${EOS_DATA_DIR}/output"
ENV EOS_CONFIG_DIR="${EOS_DATA_DIR}/config"
ENV MPLCONFIGDIR="${EOS_DATA_DIR}/mplconfigdir"

# Overwrite when starting the container in a production environment
ENV EOS_SERVER__EOSDASH_SESSKEY=s3cr3t

# Set environment variables to reduce threading needs
ENV OPENBLAS_NUM_THREADS=1
ENV OMP_NUM_THREADS=1
ENV MKL_NUM_THREADS=1
ENV PIP_PROGRESS_BAR=off
ENV PIP_NO_COLOR=1

# Generic environment
ENV LANG=C.UTF-8
ENV VENV_PATH=/opt/venv
# - Use .venv for python commands
ENV PATH="$VENV_PATH/bin:$PATH"

WORKDIR ${EOS_DIR}

# Create eos user and data directories with eos user permissions
RUN apt-get update && apt-get install -y --no-install-recommends adduser \
    && adduser --system --group --no-create-home eos \
    && mkdir -p "${EOS_DATA_DIR}" \
    && chown -R eos:eos "${EOS_DATA_DIR}" \
    && mkdir -p "${EOS_CACHE_DIR}" "${EOS_OUTPUT_DIR}" "${EOS_CONFIG_DIR}" "${MPLCONFIGDIR}" \
    && chown -R eos:eos "${EOS_CACHE_DIR}" "${EOS_OUTPUT_DIR}" "${EOS_CONFIG_DIR}" "${MPLCONFIGDIR}"

# Install build dependencies (Debian)
# - System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-venv \
    gcc g++ gfortran \
    libopenblas-dev liblapack-dev \
    pkg-config python3-dev\
    libjpeg62 \
    && rm -rf /var/lib/apt/lists/*

# - Create venv
RUN python3 -m venv ${VENV_PATH}

# - Upgrade pip inside venv
RUN pip install --upgrade pip setuptools wheel

# - Install deps with ARM7 optimization
COPY requirements.txt .

# ARM7 optimization: Detect architecture and use piwheels for precompiled wheels
RUN ARCH=$(uname -m) && \
    echo "Building for architecture: $ARCH" && \
    if [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armhf" ]; then \
        echo "ARM7 detected - using piwheels for precompiled wheels"; \
        # Install heavy scientific packages from piwheels first
        pip install --no-cache-dir \
            --index-url https://www.piwheels.org/simple \
            --extra-index-url https://pypi.org/simple \
            numpy==2.4.2 \
            scipy==1.17.0 \
            pandas==2.3.3 \
            matplotlib==3.10.8 \
            scikit-learn==1.8.0 \
            statsmodels==0.14.6 \
            contourpy==1.3.3 \
            bokeh==3.8.2 \
            pillow==12.1.0 \
            pendulum==3.2.0 \
            psutil==7.2.2 && \
        # Install remaining packages normally
        pip install --no-cache-dir \
            --extra-index-url https://www.piwheels.org/simple \
            -r requirements.txt; \
    else \
        echo "Non-ARM7 architecture - using standard PyPI"; \
        pip install --no-cache-dir -r requirements.txt; \
    fi

# Install EOS/ EOSdash
# - Copy source
COPY src/ ./src
COPY pyproject.toml .

# - Create version information
COPY scripts/get_version.py ./scripts/get_version.py
RUN python scripts/get_version.py > ./version.txt
RUN rm ./scripts/get_version.py

RUN echo "Building Akkudoktor-EOS with Python $PYTHON_VERSION on $(uname -m)"

# - Install akkudoktoreos package in editable form (-e)
# - pyproject-toml will read the version from version.txt
RUN pip install --no-cache-dir -e .

ENTRYPOINT []

EXPOSE 8504
EXPOSE 8503

# Ensure EOS and EOSdash bind to 0.0.0.0
# EOS is started with root provileges. EOS will drop root proviledges and switch to user eos.
CMD ["python", "-m", "akkudoktoreos.server.eos", "--host", "0.0.0.0", "--run_as_user", "eos"]

# Persistent data
# (Not recognized by home assistant add-on management, but there we have /data anyway)
VOLUME ["${EOS_DATA_DIR}"]

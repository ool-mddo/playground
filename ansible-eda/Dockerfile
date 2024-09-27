FROM quay.io/ansible/ansible-rulebook:v1.1.1
ARG USER_ID=1001
#ARG USER_ID=${USER_ID:-1001}
ARG STATIC_ROOT=/var/lib/eda/static
USER 0

# python3.11 and python3.12 supported
ARG PYTHON_BIN="python3.11"

RUN pip install paramiko \
    jmespath \
    netaddr \
    pynetbox \
    ttp \
    ansible-pylibssh \
    xmltodict
RUN ansible-galaxy collection install ansible.netcommon \
    ansible.utils \
    netbox.netbox \
    junipernetworks.junos \
    cisco.iosxr \
    arista.eos \
    community.general

USER "$USER_ID"
ENV POETRY_VERSION="1.8.3" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    POETRY_NO_INTERACTION=1 \
    VIRTUAL_ENV=/app/venv \
    SOURCES_DIR=/app/src \
    PATH="/app/.local/bin:$PATH" \
    HOME="/app"
CMD ["aap-eda-manage", "runserver", "0.0.0.0:8000"]

FROM python:3.11

ENV POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_CREATE=false \
  POETRY_CACHE_DIR='/var/cache/pypoetry' \
  POETRY_HOME='/usr/local'

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

RUN curl -sSL https://install.python-poetry.org | python3 -

WORKDIR /code

COPY ./image_build/domainradar-input/ /code/

RUN poetry install --no-interaction --no-ansi

ENTRYPOINT poetry run prefilter
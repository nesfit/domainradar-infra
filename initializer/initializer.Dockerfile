FROM docker.io/apache/kafka:3.8.0

WORKDIR /scripts
USER root
COPY ./wait_for_startup.sh ./
COPY ./prepare_topics.sh ./
RUN chown appuser:appuser *

USER appuser
ENTRYPOINT ./wait_for_startup.sh && ./prepare_topics.sh && sleep 1

FROM docker.io/apache/kafka:3.7.0

WORKDIR /scripts
USER root
COPY kafka_scripts/wait_for_startup.sh ./
COPY kafka_scripts/prepare_topics.sh ./
RUN chown appuser:appuser *

USER appuser
ENTRYPOINT ./wait_for_startup.sh && ./prepare_topics.sh && sleep 1

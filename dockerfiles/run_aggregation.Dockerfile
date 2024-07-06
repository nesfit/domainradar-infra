FROM ghcr.io/rtsp/docker-mongosh:latest

ENV MONGO_URI=mongodb://mongo:27017
ENV MONGO_USERNAME=admin
ENV AGGREGATION=mongo_result_aggregation_without_history.js
ENV PERIOD_SEC=30
ENV SECRET_FILE=/run/secrets/mongo_master_password

RUN mkdir /mongo
COPY ./mongo_aggregations/ /mongo

WORKDIR /mongo
RUN chmod +x run_periodically.sh

ENTRYPOINT ./run_periodically.sh "$MONGO_URI" "$AGGREGATION" "$PERIOD_SEC" \
    --username "$MONGO_USERNAME" --authenticationDatabase admin \
    --password "$(cat $SECRET_FILE | tr -d '\r''\n')"

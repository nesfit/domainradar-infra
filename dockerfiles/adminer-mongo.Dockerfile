FROM adminer:latest
USER root

RUN apt-get update && \
    apt-get install -y php-mongodb
#RUN echo "extension=mongodb.so" > /usr/local/etc/php/conf.d/docker-php-ext-mongodb.ini

USER adminer
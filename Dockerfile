FROM google/dart

EXPOSE 8080
ENV DARTLERY_MONGO mongodb://127.0.0.1/dartlery
ENV DARTLERY_LOG INFO

WORKDIR /app
VOLUME /app/data

RUN echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list && apt-get -q update && apt-get install --no-install-recommends -y -q ffmpeg

ADD shared/pubspec.yaml /build/shared/pubspec.yaml
ADD server/pubspec.yaml /build/server/pubspec.yaml

RUN cd /build/server && pub get

ADD api_client/pubspec.yaml /build/api_client/pubspec.yaml
ADD web_client/pubspec.yaml /build/web_client/pubspec.yaml

RUN cd /build/web_client && pub get

ADD . /build

RUN cd /build/web_client && pub build && mv build/web /app/ && cd /build/server && dart --snapshot=/app/server.snapshot bin/server.dart && cd / && rm /build -R

CMD []
ENTRYPOINT ["/usr/bin/dart", "server.snapshot"]
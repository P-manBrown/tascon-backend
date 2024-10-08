# syntax=docker/dockerfile:1
FROM nginx:1.27.2

ARG USER_NAME=nginx
ENV TZ=Asia/Tokyo

RUN rm -f /etc/nginx/conf.d/*
COPY ./nginx/nginx.conf /etc/nginx/
COPY ./nginx/conf.d/. /etc/nginx/templates/

RUN <<-EOF
	set -eu
	chown -R "${USER_NAME}" /etc/nginx
	chown -R "${USER_NAME}" /var/cache/nginx
EOF
USER ${USER_NAME}

EXPOSE 8080

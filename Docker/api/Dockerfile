# syntax=docker/dockerfile:1
FROM ruby:3.3.5

ARG PROJECT_NAME
ARG USER_NAME
ENV TZ=Asia/Tokyo

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/cache/apt,sharing=locked <<-EOF
		set -e
		rm -f /etc/apt/apt.conf.d/docker-clean
		apt-get update -qq
		apt-get install -y --no-install-recommends libvips42
EOF

RUN <<-EOF
	set -eu
	adduser "${USER_NAME}"
	chown -R "${USER_NAME}" "${GEM_HOME}"
EOF
USER ${USER_NAME}

RUN mkdir -p "/home/${USER_NAME}/.cache"
WORKDIR /home/${USER_NAME}/${PROJECT_NAME}
COPY --chown=${USER_NAME} ./Gemfile* /home/${USER_NAME}/${PROJECT_NAME}/
RUN --mount=type=cache,uid=1000,target=/home/${USER_NAME}/.cache/bundle <<-EOF
	set -eu
	GEM_HOME="/home/${USER_NAME}/.cache/bundle" bundle install
	cp -aRT "/home/${USER_NAME}/.cache/bundle" "${GEM_HOME}"
EOF

RUN mkdir -p "/home/${USER_NAME}/${PROJECT_NAME}/tmp/sockets"

CMD ["bin/bundle", "exec", "puma", "-C", "./config/puma.rb"]

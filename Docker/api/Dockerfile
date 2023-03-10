# syntax=docker/dockerfile:1
FROM ruby:3.2.1

ARG PROJECT_NAME
ARG USER_NAME
ENV TZ=Asia/Tokyo

RUN <<-EOF
	set -eu
	adduser "${USER_NAME}"
	chown -R "${USER_NAME}" "${GEM_HOME}"
EOF
USER ${USER_NAME}

RUN mkdir -p "/home/${USER_NAME}/.cache"
WORKDIR /home/${USER_NAME}/${PROJECT_NAME}
COPY --chown=${USER_NAME} ./Gemfile* /home/${USER_NAME}/${PROJECT_NAME}/
RUN --mount=type=secret,uid=1000,id=github-credentials,required \
		--mount=type=cache,uid=1000,target=/home/${USER_NAME}/.cache/bundle <<-EOF
			set -aeu
			. /run/secrets/github-credentials
			GEM_HOME="/home/${USER_NAME}/.cache/bundle" bundle install
			cp -aRT "/home/${USER_NAME}/.cache/bundle" "${GEM_HOME}"
EOF

RUN mkdir -p "/home/${USER_NAME}/${PROJECT_NAME}/tmp/sockets"

CMD ["bin/bundle", "exec", "puma", "-C", "./config/puma.rb"]

# TODO the versions are left unspecified intentionally, must devise some gem compatibility test suite
FROM ruby

RUN bash -c 'apt update; apt -y install ffmpeg sox'

WORKDIR /ffmprb

ADD . .

RUN bundle update

ENTRYPOINT bundle exec
CMD ffmprb

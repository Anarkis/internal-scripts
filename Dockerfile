FROM registry.suse.com/bci/ruby:3.4

#RUN bundle config --global frozen 1

WORKDIR /app

COPY Gemfile ./
COPY sync-onepassword-secret-to-vault.rb sync-onepassword-secret-to-vault.rb
COPY where-does-it-go.rb where-does-it-go.rb
COPY justfile justfile
COPY lib lib
COPY templates templates

RUN bundle install

#CMD [ "ruby", "./main-script.rb" ]

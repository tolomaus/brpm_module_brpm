FROM bmcrlm/brpm_content_framework
MAINTAINER Niek Bartholomeus <niek.bartholomeus@gmail.com>

ENV MODULE brpm_module_brpm
ENV VERSION 0.1.37

RUN gem install $MODULE -v $VERSION && \
    cd $GEM_HOME/gems/$MODULE-$VERSION && \
    bundle install && \
    rm -rf $GEM_HOME/cache

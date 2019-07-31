FROM runtimeverificationinc/ubuntu:bionic

RUN    apt-get update                                                         \
    && apt-get upgrade --yes                                                  \
    && apt-get install --yes                                                  \
        autoconf bison clang-8 cmake curl flex gcc libboost-test-dev          \
        libcrypto++-dev libffi-dev libjemalloc-dev libmpfr-dev libprocps-dev  \
        libprotobuf-dev libsecp256k1-dev libssl-dev libtool libyaml-dev lld-8 \
        llvm-8-tools make maven opam openjdk-11-jdk pandoc pkg-config         \
        protobuf-compiler python3 python-pygments python-recommonmark         \
        python-sphinx time zlib1g-dev

COPY deps/k/haskell-backend/src/main/native/haskell-backend/scripts/install-stack.sh /.install-stack/
RUN /.install-stack/install-stack.sh

RUN    git clone 'https://github.com/z3prover/z3' --branch=z3-4.6.0 \
    && cd z3                                                        \
    && python scripts/mk_make.py                                    \
    && cd build                                                     \
    && make -j8                                                     \
    && make install                                                 \
    && cd ../..                                                     \
    && rm -rf z3

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get install --yes nodejs
RUN npm install -g npx

USER user:user

COPY --chown=user:user deps/ /home/user/deps/

RUN ./deps/k/llvm-backend/src/main/native/llvm-backend/install-rust
RUN ./deps/k/k-distribution/src/main/scripts/bin/k-configure-opam-dev
RUN    cd deps/k/haskell-backend/src/main/native/haskell-backend/ \
    && stack build --only-snapshot

ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PATH=/home/user/.local/bin:/home/user/.cargo/bin:$PATH

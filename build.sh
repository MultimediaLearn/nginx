#! /bin/bash

set -x
auto/configure    \
    --with-debug \
    --with-cc-opt='-O0 -g' \
    --prefix=out/ \
    --with-http_ssl_module \
    --with-stream \
    --add-module=../nginx-http-flv-module \
    --add-module=../nginx-hello-module \
&& make -j install

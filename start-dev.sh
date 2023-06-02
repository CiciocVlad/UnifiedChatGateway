#!/usr/bin/env bash

(cd `dirname $0` && \
     make && \
     iex --sname unified_chat_gateway --cookie pcp -S mix phx.server --no-compile)

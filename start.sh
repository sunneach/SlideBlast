#!/bin/sh
export NITROGEN_SRC=./deps/nitrogen
export RIAK_SRC=./deps/riak
cd `dirname $0`

echo Creating link to nitrogen support files...
rm -rf wwwroot/nitrogen
ln -s ../$NITROGEN_SRC/www wwwroot/nitrogen

echo Starting Nitrogen on Inets...
erl \
	-name slideblast@127.0.0.1 \
	-pa $PWD/apps $PWD/ebin $PWD/include \
	-pa $NITROGEN_SRC/ebin $NITROGEN_SRC/include \
	-pa $NITROGEN_SRC/deps/*/ebin $NITROGEN_SRC/deps/*/include \
	-pa $RIAK_SRC/ebin $RIAK_SRC/include \
	-pa $RIAK_SRC/deps/*/ebin $RIAK_SRC/deps/*/include \
	-s make all \
	-eval "application:start(sasl)" \
	-eval "application:start(crypto)" \
    -eval "application:start(caster)"


#!/bin/sh
# start SlideBlast as unix daemon
# by Serge "sunneach" onerlang.blogspot.com
#
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
export BLAST=/home/serge/src/SlideBlast
export NITROGEN_SRC=$BLAST/deps/nitrogen
export RIAK_SRC=$BLAST/deps/riak
export MOCHIWEB_SRC=$BLAST/deps/riak/deps/webmachine/deps/mochiweb
export HEART_COMMAND=$BLAST/blast.sh
export ERL_LIBS=/usr/local/lib/erlang/lib

cd $BLAST

rm -rf $BLAST/wwwroot/nitrogen
ln -s $NITROGEN_SRC/www $BLAST/wwwroot/nitrogen

ulimit -n 2048

/usr/local/bin/erl -detached -heart \
    	-name slideblast@127.0.0.1 \
    	-pa $PWD/apps $PWD/ebin $PWD/include \
    	-pa $NITROGEN_SRC/ebin $NITROGEN_SRC/include \
    	-pa $NITROGEN_SRC/deps/*/ebin $NITROGEN_SRC/deps/*/include \
    	-pa $RIAK_SRC/ebin $RIAK_SRC/include \
    	-pa $RIAK_SRC/deps/*/ebin $RIAK_SRC/deps/*/include \
    	-pa $MOCHIWEB_SRC/ebin $MOCHIWEB_SRC/include \
    	-pa $MOCHIWEB_SRC/deps/*/ebin $MOCHIWEB_SRC/deps/*/include \
    	-simple_bridge_max_post_size 10 \
    	-eval "application:start(sasl)" \
    	-eval "application:start(crypto)" \
        -eval "application:start(caster)"

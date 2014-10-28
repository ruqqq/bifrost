#!/bin/bash
realdir=$(cd $(dirname $0)/$(dirname $(readlink $0)); pwd)
coffee "$realdir/app.coffee" $@
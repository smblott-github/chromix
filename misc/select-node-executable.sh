#!/bin/sh

if ! which sed > /dev/null
then
   exit 0
fi

node='node'
nodejs='nodejs'

if ! which $node && which $nodejs
then
   node=$nodejs
fi > /dev/null 2>&1

sed -i "1 s@.*@#!/usr/bin/env $node@" snapshots/*.js

exit 0

#!/bin/sh

have_executable ()
{
   which $1 > /dev/null 2>&1
}

have_executable sed \
   || exit 0

for node in node nodejs
do
   if have_executable $node
   then
      sed -i "1 s@.*@#!/usr/bin/env $node@" snapshots/*.js
      exit 0
   fi
done

exit 0

#!/bin/sh

have ()
{
   which $1 > /dev/null 2>&1
}

if ! have sed
then
   exit 0
fi

for node in node nodejs
do
   if have $node
   then
      sed -i "1 s@.*@#!/usr/bin/env $node@" snapshots/*.js
      echo "chromix: using $node" >&2
      exit 0
   fi
done

exit 0

#!/usr/bin/env bash
#####################################
# Ubuntu Install Script by WildEyes #
#####################################
# INSDIR is where I put all my libs.
# IMPORTANT : Place INSDIR on your PATH, or change it so it will be on your PATH.
INSDIR="$HOME/code/libs"
# SERVER is the name of a script that you'll run to get up the chromix server once before a development session
SERVER="$INSDIR/start-chromix-server.sh"
# Installing nodejs and chromix-dependencies
sudo add-apt-repository --yes ppa:chris-lea/node.js
sudo apt-get install --yes nodejs
cd $INSDIR
# Installing as per https://github.com/smblott-github/chromix
git clone https://github.com/smblott-github/chromix.git
cd chromix
npm install
cake build

echo '#!/usr/bin/env bash \nnode '$INSDIR'/chromix/script/server.js' > $d
chmod +x $SERVER

# #####################################################################
# Configurables ...

config =
  port: "7441" # For URI of server.

# #####################################################################
# Options ...

args = require "optimist" 
args = args.usage "Usage: $0 [--port=PORT]"
args = args.default "port", config.port
args = args.argv

# #####################################################################
# Utilities ...

print = require('sys').print
echo  = (msg) -> print "#{msg}\n"

# #####################################################################
# Web socket and handler ...

WSS  = require("ws").Server
wss  = new WSS { port: args.port }
cxs  = []

handler = (msg) ->
  echo msg.split(/\s+/).map(decodeURIComponent).join " "
  errors = []
  cxs.forEach (cx,i) ->
    try
      cx.send msg
    catch error
      errors.push i
  for i in errors.reverse()
    cxs.splice i, 1

wss.on "connection",
  (ws) ->
    cxs.push ws
    ws.on "message", handler


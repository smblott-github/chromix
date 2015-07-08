
# #####################################################################
# Configurables ...

config =
  port: "7441" # For URI of server.
  host: "localhost" # Bind to address

# #####################################################################
# Options ...

optimist = require "optimist"
args = optimist.usage("Usage: $0 [--port=PORT] [--host=ADDRESS]")
  .alias("h", "help")
  .default("port", config.port)
  .default("host", config.host)
  .argv

# #####################################################################
# Display usage ...

if args.help
  optimist.showHelp()
  process.exit(0)

# #####################################################################
# Utilities ...

print = console.log
echo  = (msg) -> print "#{msg}"

# #####################################################################
# Web socket and handler ...

WSS  = require("ws").Server
wss  = new WSS { port: args.port, host: args.host }
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


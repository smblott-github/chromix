

# #####################################################################
# Configurables ...

home   = process.env.HOME
config =
  port:  7441
  host: "localhost"
  dir:  "#{home}/.chromix_server"
  sock: "#{home}/.chromix_server/chromix_server.sock"
  debug: false

# #####################################################################
# Options ...

optimist = require "optimist"
args = optimist.usage("Usage: $0 [--port=PORT] [--host=ADDRESS]")
  .alias("h", "help")
  .default("port", config.port)
  .default("host", config.host)
  .default("debug", config.debug)
  .argv

if args.debug
  args.port += 1

# #####################################################################
# Display usage ...

if args.help
  optimist.showHelp()
  process.exit(0)

# #####################################################################
# Utilities ...

print = require('sys').print
echo  = (msg) -> print "#{msg}\n"
timeoutSet = (ms,callback) -> setTimeout callback, ms

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

# #####################################################################
# Unix domain socket...

fs  = require "fs"
net = require 'net'

if not fs.existsSync config.dir
  fs.mkdirSync config.dir, 0o0700

if fs.existsSync config.sock
  fs.unlinkSync config.sock

server = net.createServer (c) ->
  c.on 'data', (d) ->
    c.write "#{d} to you too"

server.listen config.sock

timeoutSet 1000, ->
  client = net.connect config.sock, ->
    client.write "abbbbaaa"

  client.on "data", (ans) ->
    echo ans


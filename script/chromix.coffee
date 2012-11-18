
# #####################################################################
# Setup and constants.

WS        = require "ws"

conf      = require "optimist" 
conf      = conf.usage "Usage: $0 [--port=PORT] [--server=SERVER]" 
conf      = conf.default "port", 7441 
conf      = conf.default "server", "localhost" 
conf      = conf.default "timeout", "500" 
conf      = conf.argv

chromi    = "chromi"
chromiCap = "Chromi"
msg       = conf._.map(encodeURIComponent).join " "

# #####################################################################
# Utilities.

json = (x) -> JSON.stringify x

echo = (msg, where = process.stdout) ->
  switch typeof msg
    when "string"
      # Do nothing.
      true
    when "list"
      msg = msg.join " "
    when "object"
      msg = json msg
    else
      msg = json msg
  where.write "#{msg}\n"

echoErr = (msg, die = false) ->
  echo msg, process.stderr
  process.exit 1 if die

# #####################################################################
# Web socket utility.

# TODO: Move web socket outside of `wsDo` so that it can be reused.
#
wsDo = (func, args, callback) ->
  id = Math.floor Math.random() * 2000000000
  ws = new WS("ws://#{conf.server}:#{conf.port}/")
  setTimeout ( -> process.exit 1 ), conf.timeout
  msg = [ func, JSON.stringify [ args ] ].map(encodeURIComponent).join " "
  ws.on "open", -> ws.send "#{chromi} #{id} #{msg}"
  ws.on "error", (error) -> echoErr JSON.stringify(error), true
  ws.on "message",
    (m) ->
      msg = m.split(/\s+/).map(decodeURIComponent)
      [ signal, msgId, type ] = msg
      return unless signal == chromiCap and msgId == id.toString()
      switch type
        when "info"
          echoErr msg
        when "done"
          callback.apply null, JSON.parse msg[3] if callback
        when "error"
          echoErr msg, true
          process.exit 1
        else
          echoErr msg

# #####################################################################
# Test.

wsDo "chrome.windows.getAll", { populate:true }, (wins) ->
  for win in wins
    echo win.id
    echo win
    for tab in win.tabs
      echo tab.id
      echo tab.url
  process.exit 0


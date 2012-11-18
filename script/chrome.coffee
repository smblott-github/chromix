
# ######################################################################
# Setup.

WS      = require "ws"
args    = require      "optimist" 
args    = args.usage   "Usage: $0 [--port=PORT] [--server=SERVER] [--timeout=MS_TIMEOUT]" 
args    = args.default "port", 7441 
args    = args.default "server", "localhost" 
args    = args.default "timeout", 500 
args    = args.argv

chrome  = "chrome"
done    = "done"
info    = "info"
error   = "error"

# ######################################################################
# Utilities.

echo = (msg, where = process.stdout) ->
  msg = msg.join(" ") if typeof(msg) isnt "string"
  where.write "#{msg}\n"

echoErr = (msg, die = false) ->
  echo msg, process.stderr
  process.exit 1 if die

# ######################################################################
# Web socket.

wsDo = (msg, callback) ->
  id = Math.floor Math.random() * 2000000000
  ws = new WS("ws://#{args.server}:#{args.port}/")
  setTimeout ( -> process.exit 1 ), args.timeout
  ws.on "open", -> ws.send "#{id} #{chrome} #{msg.map(encodeURIComponent).join " "}"
  ws.on "message",
    (msg) ->
      splits = msg.split(/\s+/).map(decodeURIComponent)
      # Is the message for us?
      return unless 4 == splits.length and
        splits[0] is chrome and
        splits[2] is id.toString()
      # Process message.
      switch splits[1]
        when done
          callback JSON.parse splits[3]
        when info
          echoErr splits
        when error
          echoErr splits, true
        else
          echoErr [ "unrecognised message:" ].concat(splits), true

# #####################################################################
# Tab selectors.

class Selector
  selector: {}

  fetch: (pattern) ->
    return @selector[pattern] if @selector[pattern]
    regexp = new RegExp pattern
    @selector[pattern] = (_,tab) -> regexp.test tab.url

  constructor: ->
    @selector.all      = (_,tab) -> true
    @selector.active   = (_,tab) -> tab.active
    @selector.current  = (_,tab) -> tab.active
    @selector.other    = (_,tab) -> ! tab.active
    @selector.inactive = (_,tab) -> ! tab.active
    @selector.normal   = @fetch "https?://"
    @selector.http     = @fetch "https?://"
    @selector.file     = @fetch "file://"
    @selector.slidy    = @fetch "file://.*/slidy/.*html(#\\d+)?[^/]*"

selector = new Selector()

# #####################################################################
# Handler utilities.

tabDo = (predicate, process, done=null) ->
  wsDo [ "tabs" ],
    (wins) ->
      count = 0
      for win in ( wins.filter (w) -> w.type == "normal" )
        for tab in ( win.tabs.filter (t) -> predicate win, t )
          process tab
          count += 1
      done count if done

# #####################################################################
# Handlers.

handlers =
  focus: (what) ->
    tabDo selector.fetch(what),
      (tab) ->
        "?????"

# #####################################################################
# 

# wsDo [ "tabs" ], (wins) ->
#   for w in wins
#     for t in w.tabs
#       echo [ w.id, t.id, t.url ]
#   process.exit 0

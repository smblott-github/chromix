#!/usr/bin/env node

# #####################################################################
# Imports, arguments and constants.

WebSocket = require "ws"
conf      = require "optimist" 
conf      = conf.usage "Usage: $0 [--port=PORT] [--server=SERVER]" 
conf      = conf.default "port", 7441 
conf      = conf.default "server", "localhost" 
conf      = conf.default "timeout", "500" 
conf      = conf.argv

chromi    = "chromi"
chromiCap = "Chromi"

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
    else
      msg = json msg
  where.write "#{msg}\n"

echoErr = (msg, die = false) ->
  echo msg, process.stderr
  process.exit 1 if die

# #####################################################################
# Tab selectors.
#
# The main method here is `fetch` which takes a `pattern` and yields a predicate function for testing
# window/tab pairs against that pattern.  `Selector` also serves as a cache for regular expressions.
#
class Selector
  selector: {}

  fetch: (pattern) ->
    return @selector[pattern] if pattern of @selector
    regexp = new RegExp pattern
    @selector[pattern] = (win,tab) -> win.type == "normal" and regexp.test tab.url

  constructor: ->
    @selector.window   = (win,tab) -> win.type == "normal"
    @selector.all      = (win,tab) => @fetch("window")(win,tab)
    @selector.current  = (win,tab) => @fetch("window")(win,tab) and tab.active
    @selector.other    = (win,tab) => @fetch("window")(win,tab) and not tab.active
    @selector.chrome   = (win,tab) => not @fetch("normal")(win,tab)
    @selector.normal   = (win,tab) => "http file ftp".split(" ").reduce ((p,c) => p || @fetch(c) win, tab), false
    @selector.http     = @fetch "https?://"
    @selector.file     = @fetch "file://"
    @selector.ftp      = @fetch "ftp://"
    # Synonyms.
    @selector.active   = (win,tab) => @fetch("current") win, tab
    @selector.inactive = (win,tab) => @fetch("other") win, tab

selector = new Selector()

# #####################################################################
# Web socket utilities.
#
# A single instance of the `WS` class is the only interface to the websocket.  The websocket connection is
# cached.
#
# For external use, the main method here is `do`.

class WS
  constructor: ->
    @whitespace = new RegExp "\\s+"
    @queue = []
    @ready = false
    @callbacks = {}
    @ws = new WebSocket "ws://#{conf.server}:#{conf.port}/"

    @ws.on "error",
      (error) ->
        echoErr json(error), true

    @ws.on "open",
      =>
        # Process any queued requests.  Subsequent requests will not be queued.
        @ready = true
        @queue.forEach (request) -> request()
        @queue = []

    # Handle an incoming message.
    @ws.on "message",
      (msg) =>
        msg = msg.split @whitespace
        [ signal, msgId, type, response ] = msg
        # Is the message for us?
        return unless signal == chromiCap and @callbacks[msgId]
        switch type
          when "info"
            # Quietly ignore these.
            true
          when "done"
            @callback msgId, response
          when "error"
            @callback msgId
          else
            echoErr msg

  # Send a request to chrome.
  # If the websocket is already connected, then the request is sent immediately.  Otherwise, it is cached
  # until the websocket's "open" event fires.
  send: (msg, callback) ->
    id = @createId()
    request = =>
      @register id, callback
      @ws.send "#{chromi} #{id} #{msg}"
    if @ready then request() else @queue.push request

  register: (id, callback) ->
    # Add `callback` to a dict of callbacks hashed on their request `id`.
    @callbacks[id] = callback
    #  Set timeout,  Timeouts are never cancelled.  If the request has successfully completed by the time the
    #  timeout fires, then the callback will already have been removed from the list of callbacks (so it's
    #  safe).
    setTimeout ( => if @callbacks[id] then process.exit 1 else true ), conf.timeout 

  # Invoke the callback for the indicated request `id`.
  callback: (id, argument=null) ->
    if @callbacks[id]
      callback = @callbacks[id]
      delete @callbacks[id]
      callback argument

  # `func`: a string of the form "chrome.windows.getAll"
  # `args`: a list of arguments for `func`
  # `callback`: will be called with the response from chrome; the response is `undefined` if the invocation
  #             failed in any way; see the chromi server's output to trace what may have gone wrong.
  #
  # All JSON and URI encoding/decoding are handled here.
  do: (func, args, callback) ->
    msg = [ func, json args ].map(encodeURIComponent).join " "
    @send msg, (response) -> callback.apply null, JSON.parse decodeURIComponent response

  # TODO: Use IP address/port for ID?
  #
  createId: -> Math.floor Math.random() * 2000000000

ws = new WS()

# #####################################################################
# Tab utilities.

# Traverse tabs, applying `eachTab` to all tabs which match `predicate`.  When done, call `done` with a count
# of the number of matching tabs.
#
# `eachTab` must accept three arguments: a window, a tab and a callback (which it *must* invoke after
# completing its own work).
#
tabDo = (predicate, eachTab, done) ->
  ws.do "chrome.windows.getAll", [{ populate:true }],
    (wins) ->
      count = 0
      intransit = 0
      for win in wins
        for tab in ( win.tabs.filter (t) -> predicate win, t )
          count += 1
          intransit += 1
          eachTab win, tab, ->
            # Defer this callback at least until the next tick of the event loop.  If `eachTab` is
            # synchronous, then it completes immediately ... and `intransit` would be *guaranteed* to be 0.
            # So `done` would be called on each iteration.  Deferring here prevents this.
            process.nextTick ->
              intransit -= 1
              done count if intransit == 0
      done count if count == 0

# A simple utility for constructing callbacks suitable for use with `ws.do`.
tabCallback = (tab, name, callback) ->
  (response) ->
    echo "done #{name}: #{tab.id} #{tab.url}"
    callback() if callback

# If there is an existing window, call `callback`, otherwise create one and call `callback`.
requireWindow = (callback) ->
  tabDo selector.fetch("window"),
    # eachTab.
    (win, tab, callback) -> callback()
    # Done.
    (count) -> if 0 < count then callback() else ws.do "chrome.windows.create", [{}], (response) -> callback()

# Call `work` if test is true, otherwise output error `msg` and call `callback`.
doIf = (test, msg, callback, work) ->
  if test
    # We assume that `work` itself eventually calls `callback`.
    work()
  else
    echoErr msg
    callback 1

# #####################################################################
# Operations:
#   - `tabOperations` these require a tab are not callable directly (they're called using `with`).
#   - `generalOperations` the main operations.

tabOperations =

  # Focus tab.
  focus:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid focus: #{msg}", callback,
        -> ws.do "chrome.tabs.update", [ tab.id, { selected: true } ], tabCallback tab, "focus", callback
        
  # Reload tab.
  reload:
    ( msg, tab, callback, bypassCache=false) ->
      doIf msg.length == 0, "invalid reload: #{msg}", callback,
        -> ws.do "chrome.tabs.reload", [ tab.id, {bypassCache: bypassCache} ], tabCallback tab, "reload", callback
        
  # Reload tab -- but bypass cache.
  reloadWithoutCache:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid reloadWithoutCache: #{msg}", callback,
        => @reload msg, tab, callback, true
        
  # Close tab.
  close:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid close: #{msg}", callback,
        -> ws.do "chrome.tabs.remove", [ tab.id ], tabCallback tab, "close", callback

  # Goto: load the indicated URL.
  # Typically used with "with current", either explicitly or implicitly.
  goto:
    ( msg, tab, callback) ->
      doIf msg.length == 1, "invalid goto: #{msg}", callback,
        -> ws.do "chrome.tabs.update", [ tab.id, { selected: true, url: msg[0] } ], tabCallback tab, "goto", callback

  # List tab details to stdout.
  list:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid list: #{msg}", callback,
        ->
          echo "#{tab.id} #{tab.url} #{tab.title}"
          callback()

generalOperations =

  # Ensure chrome has at least one window open.
  window:
    (msg, callback) ->
      doIf msg.length == 0, "invalid window: #{msg}", callback,
        -> requireWindow -> callback()

  # Locate all tabs matching `url` and focus it.  Normally, there should be just one match or none.
  # If there is no match, then create a new tab and load `url`.
  # When done, call `callback` (if provided).
  # If the URL of a matching tab is of the form "file://...", then the file is additionally reloaded.
  load:
    (msg, callback) ->
      doIf msg.length == 1, "invalid load: #{msg}", callback,
        ->
          url = msg[0]
          requireWindow ->
            tabDo selector.fetch(url),
              # `eachTab`
              (win, tab, callback) ->
                tabOperations.focus [], tab, ->
                  if selector.fetch("file") win, tab then tabOperations.reload [], tab, callback else callback()
              # `done`
              (count) ->
                if count == 0
                  ws.do "chrome.tabs.create", [{ url: url }],
                    (response) ->
                      echo "done create: #{url}"
                      callback()
                else
                  callback()

  # Apply one of `tabOperations` to all matching tabs.
  with:
    (msg, callback, predicate=null) ->
      doIf (1 <= msg.length and predicate) or (2 <= msg.length and not predicate), "invalid with: #{msg}", callback,
        ->
          if not predicate
            [ what ] = msg.splice 0, 1
            predicate = selector.fetch(what)
          #
          tabDo predicate,
            # `eachTab`
            (win, tab, callback) ->
              cmd = msg[0]
              if cmd and tabOperations[cmd]
                tabOperations[cmd] msg[1..], tab, callback
              else
                echoErr "invalid with command: #{cmd}", true
            # `done`
            (count) ->
              callback()

  # Apply one of `tabOperations` to all *not* matching tabs.
  without:
    (msg, callback) ->
      doIf 2 <= msg.length, "invalid without: #{msg}", callback,
        =>
          [ what ] = msg.splice 0, 1
          @with msg, callback, (win,tab) -> not selector.fetch(what) win, tab

  ping:
    (msg, callback) ->
      doIf msg.length == 0, "invalid ping: #{msg}", callback,
        -> ws.do "", [], (response) -> callback()

  # Output a list of all chrome bookmarks.  Each output line is of the form "URL title".
  bookmarks:
    (msg, callback, output=null, bookmark=null) ->
      doIf msg.length == 0, "invalid bookmarks: #{msg}", callback,
        =>
          if not bookmark
            # First time through (this *is not* a recursive call).
            ws.do "chrome.bookmarks.getTree", [],
              (bookmarks) =>
                bookmarks.forEach (bmark) =>
                  @bookmarks msg, callback, output, bmark if bmark
                callback()
          else
            # All other times through (this *is* a recursive call).
            if bookmark.url and bookmark.title
              if output then output bookmark else echo "#{bookmark.url} #{bookmark.title}"
            if bookmark.children
              bookmark.children.forEach (bmark) =>
                @bookmarks msg, callback, output, bmark if bmark

  # A custom bookmark listing, just for smblott: "booky" support.
  booky: (msg, callback) ->
    regexp = new RegExp "(\\([A-Z0-9]+\\))", "g"
    @bookmarks msg, callback,
      # Output routine.
      (bmark) ->
        ( bmark.title.match(regexp) || [] ).forEach (bm) ->
          bm = bm.slice(1,-1).toLowerCase()
          echo "#{bm} #{bmark.url}"

# #####################################################################
# Execute command line arguments.

msg = conf._

# Might as well "ping" without any arguments.
msg = [ "ping" ] if msg.length == 0

# If the command is in `tabOperations`, then add "with current" to the start of it.  This gives a sensible,
# default meaning for these commands.
if msg and msg[0] and tabOperations[msg[0]] and not generalOperations[msg[0]]
  msg.unshift "with", "current"

# Try to do the work.
cmd = msg.splice(0,1)[0]
if cmd and generalOperations[cmd]
  generalOperations[cmd] msg, (code=0) -> process.exit code

else
  echoErr "invalid command: #{cmd} #{msg}", true


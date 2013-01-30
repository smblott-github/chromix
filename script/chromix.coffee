#!/usr/bin/env node

# #####################################################################
# Imports, arguments and constants.

WebSocket = require "ws"
Url       = require 'url'
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

  host: (host) ->
    (win,tab) -> Url.parse(tab.url)?.host is host

  constructor: ->
    @selector.window   = (win,tab) -> win.type == "normal"
    @selector.all      = (win,tab) => @fetch("window")(win,tab)
    @selector.current  = (win,tab) => @fetch("window")(win,tab) and tab.active
    @selector.other    = (win,tab) => @fetch("window")(win,tab) and not tab.active
    @selector.chrome   = (win,tab) => not @fetch("normal")(win,tab)
    @selector.normal   = (win,tab) => [ "http", "file", "ftp"].reduce ((p,c) => p || @fetch(c) win, tab), false
    @selector.http     = @fetch "https?://"
    @selector.file     = @fetch "file://"
    @selector.ftp      = @fetch "ftp://"
    # Synonyms.
    @selector.active   = (win,tab) => @fetch("current") win, tab
    @selector.inactive = (win,tab) => @fetch("other") win, tab
    # Pinned?
    @selector.pinned   = (win,tab) => tab.pinned


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
    @whitespace = /\s+/
    @queue = []
    @ready = false
    @callbacks = {}
    @ws = new WebSocket "ws://#{conf.server}:#{conf.port}/"

    @ws.on "error",
      (error) ->
        echoErr json(error), true # Exits.

    @ws.on "open",
      =>
        # Process any queued requests.  Subsequent requests will not be queued.
        @ready = true
        @queue.forEach (request) -> request()
        @queue = []

    # Handle an incoming message.
    @ws.on "message",
      (msg) =>
        [ signal, msgId, type, response ] = msg = msg.split @whitespace
        # Is the message for us?
        if signal == chromiCap and @callbacks[msgId]
          switch type
            when "info"
              # Quietly ignore these.
              true
            when "done"
              @callback msgId, response
            when "error"
              echoErr msg.join(" "), true # Exits.
            else
              # Should not happen?
              echoErr msg.join(" "), true # Exits.

  # Send a request to chrome.
  # If the websocket is ready, then the request is sent immediately.  Otherwise, it is queued
  # until the "open" event fires.
  send: (msg, callback) ->
    id = @createId()
    request = =>
      @register id, callback
      @ws.send "#{chromi} #{id} #{msg}"
    if @ready then request() else @queue.push request

  register: (id, callback) ->
    # Add `callback` to a dict of callbacks hashed on their request `id`.
    @callbacks[id] = callback
    #  Set timeout.  Timeouts are never cancelled.  If the request has successfully completed by the time the
    #  timeout fires, then the callback will already have been removed from the list of callbacks .. so it's
    #  safe.
    setTimeout ( => process.exit 1 if @callbacks[id] ), conf.timeout 

  # Invoke the callback for the indicated request `id`.
  callback: (id, argument=null) ->
    # We can't get here unless the callback exists.
    callback = @callbacks[id]
    delete @callbacks[id]
    callback argument

  # `func`: a string of the form "chrome.windows.getAll", say.
  # `args`: a list of arguments for `func`.
  # `callback`: will be called with the response from chrome; the response is `undefined` if the invocation
  #             failed in any way; see the chromi server's output to trace what may have gone wrong.
  #
  # All JSON and URI encoding/decoding is handled here.
  do: (func, args, callback) ->
    msg = [ func, json args ].map(encodeURIComponent).join " "
    @send msg, (response) -> callback.apply null, JSON.parse decodeURIComponent response

  # TODO: Use IP address/port for ID?
  createId: -> Math.floor Math.random() * 2000000000

ws = new WS()

# #####################################################################
# Tab utilities.

# Traverse tabs, applying `eachTab` to all tabs which match `predicate`.  When done, call `callback` with a count
# of the number of matching tabs.
#
# `eachTab` must accept three arguments: a window, a tab and a callback (which it *must* invoke after
# completing its own work).
#
tabDo = (predicate, eachTab, callback) ->
  ws.do "chrome.windows.getAll", [{ populate:true }],
    (wins) ->
      count = 0
      intransit = 0
      wins.forEach (win) ->
        win.tabs.filter((tab) -> predicate win, tab).forEach (tab) ->
          count += 1
          intransit += 1
          # eachTab is of form (win, tab, callback) -> .....
          eachTab win, tab, ->
            # Defer this callback at least until the next tick of the event loop.  If `eachTab` were
            # synchronous, then it would complete immediately ... and `intransit` would be *guaranteed* to be
            # 0.  So `callback` would be called on each iteration.  Deferring here prevents this.
            process.nextTick ->
              intransit -= 1
              callback count if intransit == 0
      callback 0 if count == 0

# A simple utility for constructing callbacks suitable for use with `ws.do`.
tabCallback = (tab, name, callback) ->
  (response) ->
    echo "done #{name}: #{tab.id} #{tab.url}"
    callback()

# If there is an existing window, call `callback`, otherwise create one and call `callback`.
requireWindow = (callback) ->
  tabDo selector.fetch("window"),
    # eachTab (a no-op, here).
    (win, tab, callback) -> callback()
    # Done.
    # `callback` argument: `true` if window created, `false` otherwise.
    (count) -> if 0 < count then callback false else ws.do "chrome.windows.create", [{}], (response) -> callback true

# Call `work` if test is true, otherwise output error `errMsg` and call `callback`.
doIf = (test, errMsg, callback, work) ->
  if test
    # We assume/require that `work` itself eventually calls `callback`.
    work()
  else
    echoErr errMsg
    callback 1

# #####################################################################
# Operations:
#   - `tabOperations` these require a tab are not callable directly (they're called using `with`).
#   - `generalOperations` the main operations.

tabOperations =

  # Focus tab.
  focus:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid focus: #{msg}", callback, ->
        ws.do "chrome.tabs.update", [ tab.id, { selected: true } ], tabCallback tab, "focus", callback
        
  # Reload tab.
  reload:
    ( msg, tab, callback, bypassCache=false) ->
      doIf msg.length == 0, "invalid reload: #{msg}", callback, ->
        ws.do "chrome.tabs.reload", [ tab.id, {bypassCache: bypassCache} ], tabCallback tab, "reload", callback
        
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

  # Goto: load the indicated URL in the current tab.
  # Typically used with "with current", either explicitly or implicitly.
  goto:
    ( msg, tab, callback) ->
      doIf msg.length == 1, "invalid goto: #{msg}", callback, ->
        ws.do "chrome.tabs.update", [ tab.id, { selected: true, url: msg[0] } ], tabCallback tab, "goto", callback

  # List tab details to stdout.
  list:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid list: #{msg}", callback, ->
        echo "#{tab.id} #{tab.url} #{tab.title}"
        callback()

  # Reload tab.
  duplicate:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid duplicate: #{msg}", callback, ->
        ws.do "chrome.tabs.duplicate", [ tab.id ], tabCallback tab, "duplicate", callback
        
  pin:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid pin: #{msg}", callback, ->
        ws.do "chrome.tabs.update", [ tab.id, { pinned: true } ], tabCallback tab, "pin", callback

  unpin:
    ( msg, tab, callback) ->
      doIf msg.length == 0, "invalid unpin: #{msg}", callback, ->
        ws.do "chrome.tabs.update", [ tab.id, { pinned: false } ], tabCallback tab, "unpin", callback

generalOperations =

  # Ensure chrome has at least one window open.
  window:
    (msg, callback) ->
      doIf msg.length == 0, "invalid window: #{msg}", callback, -> requireWindow -> callback()

  # Locate all tabs matching `url` and focus them.  Normally, there should be just one match or none.
  # If there is no match, then create a new tab and load `url`.
  # When done, call `callback`.
  # If the URL of a matching tab is of the form "file://...", then the file is additionally reloaded.
  load:
    (msg, callback) ->
      doIf msg.length == 1, "invalid load: #{msg}", callback, ->
        [ url ] = msg
        # Strip any trailing query for search.
        # (Disabled).
        urlNoQuery = url
        # qIndex = urlNoQuery.indexOf "?"
        # urlNoQuery = urlNoQuery.substring 0, qIndex if 0 < qIndex
        #
        requireWindow (created) ->
          tabDo selector.fetch(urlNoQuery),
            # `eachTab`.
            (win, tab, callback) ->
              tabOperations.focus [], tab,
                -> if selector.fetch("file") win, tab then tabOperations.reload [], tab, callback else callback()
            # `done`.
            (count) ->
              if count == 0
                # No matches, so create tab.
                ws.do "chrome.tabs.create", [{ url: url }],
                  (response) ->
                    echo "done create: #{url}"
                    if created
                      # A new window was created: so close the automatically created "New Tab".
                      generalOperations.with [ "^chrome://newtab/", "close" ], -> callback()
                    else
                      # No new window was created: so we're done.
                      callback()
              else
                # Tab found: so we're done.
                callback()

  # Locate all tabs matching `url` and focus them.  Normally, there should be just one match or none.
  # If there is no match, then create a new tab and load `url`.
  # When done, call `callback`.
  # If the URL of a matching tab is of the form "file://...", then the file is additionally reloaded.
  move:
    (msg, callback) ->
      doIf msg.length == 1, "invalid load: #{msg}", callback, ->
        [ url ] = msg
        # Strip any trailing query for search.
        # (Disabled).
        urlNoQuery = url
        #
        urlParsed = Url.parse url
        if not urlParsed.host
          return generalOperations.load msg, callback
        doneMove  = false
        # qIndex = urlNoQuery.indexOf "?"
        # urlNoQuery = urlNoQuery.substring 0, qIndex if 0 < qIndex
        #
        requireWindow (created) ->
          tabDo selector.host(urlParsed.host),
            # `eachTab`.
            (win, tab, callback) ->
              if doneMove
                callback()
              else
                doneMove = true
                tabOperations.focus [], tab, ->
                  if tab.url is url
                    callback()
                  else
                    tabOperations.goto msg, tab, callback

            # `done`.
            (count) ->
              if count == 0
                # No matches, so create tab.
                ws.do "chrome.tabs.create", [{ url: url }],
                  (response) ->
                    echo "done create: #{url}"
                    if created
                      # A new window was created: so close the automatically created "New Tab".
                      generalOperations.with [ "^chrome://newtab/", "close" ], callback
                    else
                      # No new window was created: so we're done.
                      callback()
              else
                # Tab found: so we're done.
                callback()

  # Apply one of `tabOperations` to all matching tabs.
  with:
    (msg, callback, predicate=null) ->
      doIf (1 <= msg.length and predicate) or (2 <= msg.length and not predicate), "invalid with: #{msg}", callback, ->
        if not predicate
          [ what, msg... ] = msg
          predicate = selector.fetch(what)
        #
        [ cmd, msg... ] = msg
        tabDo predicate,
          # `eachTab`.
          (win, tab, callback) ->
            if cmd and tabOperations[cmd]
              tabOperations[cmd] msg, tab, callback
            else
              echoErr "invalid with command: #{cmd}", true
          # `done`.
          (count) -> callback()

  # Apply one of `tabOperations` to all *not* matching tabs.
  without:
    (msg, callback) ->
      doIf 2 <= msg.length, "invalid without: #{msg}", callback, =>
        [ what , msg... ] = msg
        @with msg, callback, (win,tab) -> not selector.fetch(what) win, tab

  ping:
    (msg, callback) ->
      doIf msg.length == 0, "invalid ping: #{msg}", callback, ->
        ws.do "ping", [], (response) -> callback()

  newTab:
    (msg, callback) ->
      doIf msg.length == 0, "invalid newTab: #{msg}", callback, ->
        url = "chrome://newtab/"
        requireWindow (created) ->
          if created
            # A new window was created: so a new, empty tab will have been created too, so we're done.
            callback()
          else
            # Using an existing window: create a new tab.
            ws.do "chrome.tabs.create", [{ url: url }],
              (response) ->
                echo "done create new tab: #{url}"
                callback()

  # Direct access to the chrome API.
  # First argument is a string representing the API function.
  # Subsequent arguments are JSON encoded arguments for the function.
  # Example:
  #   - chromix raw chrome.tabs.update '{"pinned":true}'
  #     (amazingly, this works ... even without a tab argument)
  raw:
    (msg, callback) ->
      doIf msg.length <= 2, "invalid raw: #{msg}", callback, ->
        [ cmd, msg... ] = msg
        try
          msg = msg.map JSON.parse
        catch error
          echoErr "json parse error: #{msg}"
        ws.do cmd, msg, (response) ->
          echo response
          callback()

  # Output a list of all chrome bookmarks.  Each output line is of the form "URL title", by default.
  bookmarks:
    (msg, callback, output = (bm) -> echo "#{bm.url} #{bm.title}" ) ->
      doIf msg.length == 0, "invalid bookmarks: #{msg}", callback, =>
        recursiveBookmarks =
          (output, bookmark=null) ->
            if not bookmark
              ws.do "chrome.bookmarks.getTree", [],
                (bookmarks) ->
                  bookmarks.forEach (bmark) -> recursiveBookmarks output, bmark if bmark
                  callback()
            else
              output bookmark if bookmark.url and bookmark.title
              if bookmark.children
                bookmark.children.forEach (bmark) -> recursiveBookmarks output, bmark
        #
        recursiveBookmarks output

  # A custom bookmark listing, just for smblott: "booky" support.
  booky: (msg, callback) ->
    regexp = /(\([A-Z0-9]+\))/g
    @bookmarks msg, callback, (bmark) ->
      ( bmark.title.match(regexp) || [] ).forEach (bm) ->
        bm = bm.slice(1,-1).toLowerCase()
        echo "#{bm} #{bmark.url}"

# #####################################################################
# Execute command line arguments.

args = conf._

# "ping" seems to be a sensible default.
args = [ "ping" ] if args.length == 0

# If the command is in `tabOperations`, then add "with current" to the start of it.  This gives a sensible,
# default meaning for these commands.
if args and args[0] and tabOperations[args[0]] and not generalOperations[args[0]]
  args.unshift "with", "current"

# Try to do the work.
[ cmd, args... ] = args
if cmd and generalOperations[cmd]
  generalOperations[cmd] args, (code=0) -> process.exit code

else
  echoErr "invalid command: #{cmd} #{args}", true


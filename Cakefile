
# Based on vimium Cakefile: https://github.com/philc/vimium
#

fs = require "fs"
path = require "path"
child_process = require "child_process"

spawn = (procName, optArray, silent=false) ->
  proc = child_process.spawn procName, optArray
  unless silent
    proc.stdout.on 'data', (data) -> process.stdout.write data
    proc.stderr.on 'data', (data) -> process.stderr.write data
  proc

# visitor will get passed the file path as a parameter
visitDirectory = (directory, visitor) ->
  fs.readdirSync(directory).forEach (filename) ->
    filepath = path.join directory, filename
    if (fs.statSync filepath).isDirectory()
      return visitDirectory filepath, visitor

    return unless (fs.statSync filepath).isFile()
    visitor(filepath)

task "build", "compile all coffeescript files to javascript", ->
  coffee = spawn "coffee", ["-c", __dirname]
  coffee.on 'exit', (returnCode) -> process.exit returnCode

task "clean", "removes any js files which were compiled from coffeescript", ->
  visitDirectory __dirname, (filepath) ->
    return unless (path.extname filepath) == ".js"

    directory = path.dirname filepath

    # Check if there exists a corresponding .coffee file
    try
      coffeeFile = fs.statSync path.join directory, "#{path.basename filepath, ".js"}.coffee"
    catch _
      return

    fs.unlinkSync filepath if coffeeFile.isFile()

task "autobuild", "continually rebuild coffeescript files using coffee --watch", ->
  coffee = spawn "coffee", ["-cw", __dirname]


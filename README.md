chromix
=======

Chromix is a command-line utility for controlling Google chrome.  It can be
used, amongst other things, to create, switch, focus, reload and remove tabs.

Here's a use case.  Say you're editing an
[asciidoc](http://www.methods.co.nz/asciidoc/userguide.html) or a
[markdown](http://daringfireball.net/projects/markdown/) document.  The work
flow is: edit, compile, and reload the chrome tab to see your changes.

Chromix can help automate this, particularly the last step.  Change the build step to:
```
markdown somefile.md > somefile.html && node chromix.js load file://$PWD/somefile.html
```
Now, chrome reloads your work every time it changes.  And with suitable key
bindings in your text editor, the build-view process can involve just a couple
of key strokes.

Installation
------------

Chromix depends on [Chromi](https://github.com/smblott-github/chromi).  So the
first step is to [install
chromi](https://github.com/smblott-github/chromi#installation).

The dependencies for chromix are the same as those for chromi -- see
[here](https://github.com/smblott-github/chromi#dependencies).

Chromix is compiled with `cake build` in the project's root folder.

The resulting Javascript file (`script/chromix.js`) can be made executable and
installed in some suitable directory on your `PATH`.

A chromix invocation looks something like:
```
node chromix.js CHROMIX-COMMAND [ARGUMENTS...]
```

Chromix Commands
----------------

There are two types of chromix commands: *general* commands and *tab* commands.

### General Commands

#### Ping

Example:
```
node chromix.js ping
```
This produces no output, but yields an exit code of `0` if chromix was able to
ping chrome, and non-zero otherwise.  It can be useful in scripts for checking
whether chrome is running.

#### Load

Example:
```
node chromix.js load https://github.com/
```
This first searches for a tab for which `https://github.com/` is a prefix of
the tab's URL.  If such a tab is found, it is focussed.  Otherwise, a new tab
is created for the URL.

Additionally, if the URL is of the form 'file://.*', then the tab is
reloaded.

#### With

Example:
```
node chromix.js with other close
```
This closes all tabs except the focused one.

Anotherxample:
```
node chromix.js with chrome close
```
This closes all tabs which *aren't* `http`, `file` or `ftp` protocols.

The first argument to `with` specifies what the command applies to (`other`,
above,  means "all non-focused tab"), and the second and subsequent arguments are a tab
command and *its* arguments (just `close`, above).

With `with`, tabs can be specified in a number of ways: `all`, `current`,
`other`, `http` (including HTTPS), `file`, `ftp`, `normal` (meaning `http`,
`file` or `ftp`), or `chrome` (meaning not `normal`).  Any other argument to
`with` is taken to be a pattern which is used to match tabs.  Patterns must
match from the start of the URL and may contain Javascript RegExp operators.

Here's an example:
```
node chromix.js with "file:///.*/slidy/.*.html" reload
```
This reloads all tabs containing HTML files under directories named `slidy`.

#### Without

Example:
```
node chromix.js without https://www.facebook.com/ close
```
This closes all windows *except* those within the Facebook domain.

`without` is the same as `with`, except that the test is inverted.  So
`without normal` is the same as `with normal`, and `without current` is the
same as `with other`.

#### Window

Example:
```
node chromix.js window
```
This ensures there is at least one chrome window.  It does not start chrome if chrome is not running.

#### Bookmarks

Example:
```
node chromix.js bookmarks
```
This outputs (to `stdout`) a lit of all chrome bookmarks, one per line.

#### Booky

Example:
```
node chromix.js booky
```
This outputs (to `stdout`) a list of chrome bookmarks, but in a different format.

### Tab Commands

#### Focus

Example:
```
node chromix.js with http://www.bbc.co.uk/news/ focus
```
Focus the indicated tab.

#### Reload

Example:
```
node chromix.js with http://www.bbc.co.uk/news/ reload
```
Reload the indicated tab.

#### Close

Example:
```
node chromix.js with http://www.bbc.co.uk/news/ close
```
Close the indicated tab.

#### Goto

Example:
```
node chromix.js with current goto http://www.bbc.co.uk/news/
```
Visit `http://www.bbc.co.uk/news/` in the current tab.

Notes
-----

### Implicit `with` in Tab Commands

If a tab command is used without a preceding `with` clause, then the current tab is assumed.

So, the following:
```
node chromix.js goto http://www.bbc.co.uk/news/
```
is shorthand for:
```
node chromix.js with current goto http://www.bbc.co.uk/news/
```

Closing Comments
----------------

Chromix is a work in progress and may be subject to either gentle evolution or
abrupt change.

Please let me (Steve Blott) know if you have any ideas as to how chromix might
be improved.


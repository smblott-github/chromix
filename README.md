chromix
=======

Chromix is a command-line utility for controlling Google chrome.  It can be
used, amongst other things, to create, switch, focus, reload and remove tabs.

Here's an example.  Say you're editing an
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

The resulting Javascript file (`chromix.js`) can be made executable and
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

Additionally, if the URL is of the form 'file:///....', then the tab is
reloaded.

#### With

Example:
```
node chromix.js with other close
```
This closes all tabs except the focused one.

The first argument to `with` specifies what the command applies to (`other`,
above,  means "all non-focused tab"), and the second and subsequent arguments are a tab
command and *its* arguments (`close`, above).

With `with`, tabs can be specified in a number of ways: `current`, `other`,
`http` or `file`.  Any other argument to `with` is taken to be a pattern which
is used to match tabs.  Patterns must match from the start of the URL and may
contain Javascript RegExp operators.

Here's an example:
```
node chromix.js with "file:///.*/slidy/.*.html" reload
```
Reload all tabs containing HTML files under directories named `slidy`.

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

#### Note

If a tab command is used without a preceding `with` clause, then the current tab is assumed.

So, the following:
```
node chromix.js goto http://www.bbc.co.uk/news/
```
is shorthand for
```
node chromix.js with current goto http://www.bbc.co.uk/news/
```




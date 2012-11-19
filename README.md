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
markdown somefile.md > somefile.html && chromix load file://$PWD/somefile.html
```
Now, chrome reloads your work every time it changes.  And with suitable key
bindings in your text editor, the build-view process can involve just a couple
of key strokes.




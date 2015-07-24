# The Engine Install Scripts #

Once Update Engine has downloaded an update to an application, it will
install the update using the KSAction subclass KSInstallAction. The
KSInstallAction class is very straightforward because it will only
handle one specific type of install: an Update Engine install. It will
not directly handle drag-installs or even pkg installs. These types of
installs will be handled indirectly by scripts present on the disk image.

When Update Engine mounts (read-only) a disk image to install an upgrade to an
application, it will look for
the following scripts and will execute them in order.

```
.engine_preinstall
.engine_install (required)
.engine_postinstall
```

These scripts all have a leading dot so that the DMG used for updating
the application could be the same one that customers download
directly from your company website.

They don't have to be scripts, just something executable.  So feel
free to use ObjectFORTRAN++, or one of the built in OS X scripting
languages.  Be aware of language version differences between OS
revisions.  For example, python on Tiger is version 2.3.5, which is
missing a number of features and libraries than python 2.5.1 on
Leopard.


## The Scripts ##

First up is the `.engine_install` script, which is the only script
that is required. This is what kicks off the upgrade of
your product.

"install" is used here, here because from Update Engine's perspective
it is "installing" something; likely, it's installing an update for
your application.  You could use Update Engine as a metainstaller by
providing it ticket for an application that has not been installed yet and
doing an "update".

The `.engine_preinstall` and `.engine_postinstall` scripts are both
optional.  As you'd expect, the preinstall script is run before
the install script, and then postinstall script is run last.

The distinction is academic for most products, you'll just use the
install script.  If you were installing things as root, you may want
to run the pre or post install scripts as the console user so that
they could put up user interface.  Update Engine doesn't provide this particular
functionality, though.

## Script Arguments and Environment Variables ##

Update Engine makes some information available to these install
scripts by way of command-line arguments and environment
variables. The first argument to each script (`$1` in bash-speak)
will be the absolute path to the mounted disk image, which will be the
path to where the scripts are located). This path may have spaces in
it so your scripts should quote appropriately.

These  scripts communicate with the other scripts
downstream by making each script's standard output available to the
other scripts in the form of an environment variable. This allows
scripts to communicate by echoing output that the next script could
read, grep, or process in some way.  Your scripts can simply ignore
the enviornment variables if they don't care about them.  The output
from `.engine_preinstall` script will be available in the
`KS_PREINSTALL_OUT` variable, and the output from `.engine_install`
will be stored in `KS_INSTALL_OUT`.

Update Engine will also set environment variables for all of the
key/value pairs defined in the PlistServerConfiguration file.  For
example, if the config file for you product has a key/value par with
"`foo`"="`bar`", Update Engine would set "`KS_foo`" to the value
"`bar`" in your install scripts' environment.

## Return Codes ##

Script return codes should follow normal Unix conventions where 0 means success
and anything else is considered a failure, with two exceptions:
  * `KS_INSTALL_TRY_AGAIN_LATER` (77) from `.engine_preinstall` or `.engine_install` says "try again later".
  * `KS_INSTALL_WANTS_REBOOT` (66) from `.engine_postinstall` says that a reboot will be necessary.

If the preinstall script returns `KS_INSTALL_TRY_AGAIN_LATER`, Update Engine
will immediately stop processing the update without considering it
an error.  The next time the install is attempted the
`.engine_preinstall` script is free to return the same "try again
later" value, in which case the same thing will happen again.
This can be useful for applications that want to check "is it safe
to update me now? oh, no? ok, well, I'll just have Update Engine try me
again in a little bit".

`KS_INSTALL_WANTS_REBOOT` indicates to Update Engine that a reboot is
necessary for successful completion of the update.  Update Engine
itself will not solicit or cause a reboot, but the
`-engine:finished:wasSuccess:wantsReboot:` delegate method will be
called (if supplied) with YES for `wantsReboot`.  It is up to your
program to arrange to reboot the system.

One easy way to do this is by asking `System Events` to do so with AppleScript, easily done via NSTask or [GTMScriptRunner](http://code.google.com/p/google-toolbox-for-mac/source/browse/trunk/Foundation/GTMScriptRunner.h):
```
/usr/bin/osascript -e 'tell application \"System Events\" to restart'
```

The downloaded payload for an update will be stored on-disk in a
protected directory until the install succeeds. This will make it so
the "retry later" case does not have to repeatedly download the same
update; the cached update will be used.  The hash and file size help
ensure the integrity of the downloaded payload.  Using https to serve
your update plist file will add an extra layer of security.
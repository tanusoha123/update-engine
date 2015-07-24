# Introduction #

At a high level, Update Engine is very simple. It talks to a server to
determine if installed software needs to be updated, and if so, it
downloads and installs the new software.

## Tickets ##

Update Engine knows about installed products through a set of tickets.
A ticket describes a single product to Update Engine, including:
  * Product's name or identifier, like com.google.Earth
  * Version number, like 3.1.41.59
  * URL for the product's update information, like http://example.com/snargleblaster/update.plist

Update Engine can update multiple products simply by specifying a
ticket for each product.  Tickets can be contained in a ticket store,
whether persistently on disk or just in-memory.

## Server ##

The URL in each ticket identifies a property list, abbreviated _plist_, that
contains information about that product's updates. This plist contains
a predicate that tells Update Engine whether or not the update is
needed. It also contains the URL for the new software's disk image,
the size and a hash of the new disk image, and a few other things.
More information can be found at PlistServerConfiguration

Update Engine will download this plist from the specified URL,
evaluate the rules, and then download and install all necessary
updates.

You are free to make your own subclasses of KSServer to use any protocol
with any server you want.  The plist server makes it easy to drop a
property list file on an internet host and use it for updates.

## Installing ##

To install the new software, Update Engine mounts the downloaded disk
image and runs a script that must be present at the disk image root.
This required script is ultimately responsible for upgrading
the software. This script provides a layer of abstraction that enables
Update Engine to "update" virtually any type of software.  More
information can be found at EngineInstallScripts.
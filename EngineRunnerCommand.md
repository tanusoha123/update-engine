# Engine Runner #

The EngineRunner command is one of the Update Engine sample programs.
It is a command-line tool that exposes some useful bits of Update Engine
functionality.  You can use it to experiment with Update Engine, or to
maintain ticket stores, or even to run the update process for your applicaton.
You can include the code directly in your application, or include
the EngineRunner command in your application bundle and call it directly
with NSTask or
[GTMScriptRunner](http://code.google.com/p/google-toolbox-for-mac/source/browse/trunk/Foundation/GTMScriptRunner.h)

## Command Syntax ##

The syntax for EngineRunner is

`EngineRunner _command_ -arg1 value -arg2 value -arg3 value ...`

To see all of the commands supported by EngineRunner, run it without
any commands (these are all entered into the shell on one line):

```
    $ EngineRunner
    EngineRunner supports these commands:
        add : Add a new ticket to a ticket store
        change : Change attributes of a ticket
        delete : Delete a ticket from the store
        dryrun : See if an update is needed, but don't install it
        dryrunticket : See available updates in a ticket store but don't
                       install any
        list : Lists all of the tickets in a ticket store
        run : Update a single product
        runticket : Update all of the products in a ticket store
    Run 'EngineRunner commandName -help' for help on a particular command
```

To see help on a given command run the command with the `-help` flag:

```
    $ EngineRunner change -help
    change : Change attributes of a ticket
      Required arguments:
        -productid : Product ID to change
        -store : Path to the ticket store
      Optional arguments:
        -url : New server URL
        -version : New product version
        -xcpath : New existence checker path
```

This will show you the optional and required parameters.


## Running an Update ##

To run an update, provide all of the information for the product on the
command line:

```
    $ EngineRunner run
          -productid com.greeble.hoover
          -version 1.2
          -url http://example.com/updateInfo
    finished update of com.greeble.hoover:  Success
```

If you want to see if your application would be considered updatable, use the `dryrun` command.  That goes through the motions of updating, but doesn't actually download or run anything.

```
    $ EngineRunner dryrun
          -productid com.greeble.hoover
          -version 1.2
          -url http://example.com/updateInfo
    Products that would update:
      com.greeble.hoover
```


## Manipulating Tickets ##

If you have several products you're managing, you might want to use
a ticket store to consolidate all of the update information in one place.
To add a ticket to a store, use the `add` command:

```
    $ EngineRunner add
          -store /tmp/store.tix
          -productid com.greeble.hoover
          -version 1.2
          -url http://example.com/updateInfo
          -xcpath /Applications/Greebleator.app
```


To see what tickets you have in the store, use the `list` command:

```
    $ EngineRunner list -store /tmp/store.tix
    1 tickets at /tmp/store.tix
    Ticket 0:
        com.greeble.hoover version 1.2
        exists? NO, with existence checker <KSPathExistenceChecker:0x317d60 path=/Applications/Greebleator.app>
        server URL http://example.com/updateInfo
```

The "NO" after "exists?" is the actual return value of the existence checker.
In this case, there is no `/Applications/Greebleator.app`.


## Updating With a Ticket Store ##

To see what products need an update (without actually running an update),
use `dryrunticket`:

```
    $ EngineRunner dryrunticket -store /tmp/store.tix
    No products to update
```

```
    $ EngineRunner dryrunticket -store /some/other/ticket/store.tix
    Products that would update:
      com.google.greeble
      com.google.bork
```

To actually run an update, use `runticket`:

```
    $ EngineRunner runticket -store /some/other/ticket/store.tix
    finished update of com.google.greeble:  Success
    finished update of com.google.bork:  Success
```

Or supply a productID to just update one product:

```
    $ EngineRunner runticket  -store /some/other/ticket/store.tix \
                       -productid com.google.bork
    finished update of com.google.bork:  Success
```




Update Engine provides KSPlistServer, a KSServer subclass, that
reads a property list at a given URL. This property list contains the
information that Update Engine needs to determine if an update is
needed, and where to download that update from.

# Rules #

The property list should contain a dictionary with one entry called `Rules`. Rules is a an array of dictionaries, one for each product. Each rule dictionary should have these keys:

  * **ProductID** - The unique identifier for the product (same as the product ID used in the ticket). The identifier for the product. Update Engine doesn't care about the actual contents of the ProductID. They can be bundle IDs, UUIDs, blood types or shoe sizes. Update Engine just compares them for equality with the product IDs in the tickets.

  * **Predicate** - Any NSPredicate compatible string that determines whether the update described by the current rule should be applied. There are some Update Engine specific values you can use in your predicate.

  * **Codebase** - The URL where the update should be downloaded from. This URL must reference a disk image (DMG).

  * **Hash** - The Base64-encoded SHA-1 hash of the file at the `Codebase` URL. An easy way to calculate this is with the command:
```
            `openssl sha1 -binary dmg-filename | openssl base64`
```

  * **Size** - The size in bytes of the file at the "Codebase" URL.


# Predicates #

The `Predicate` in the rule enables lots of flexibility and
configurability. The string specified for the predicate should use
Apple's
[predicate format string syntax](http://developer.apple.com/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html) and will be converted into an
NSPredicate and run against an NSDictionary with two attributes:

  * **SystemVersion** - This gives the predicate access to version information about the current OS. The value of this key is the contents of the file: `/System/Library/CoreServices/SystemVersion.plist`
  * **Ticket** -This gives the predicate access to the product's currently installed version information via its corresponding KSTicket.

The ticket itself contains several attributes.  Check out KSTicket.h
for all of them.  The most useful one would be `version`, the product
version in the ticket.  Also, any additional
Key/Value pairs from the plist file will be included in the Ticket
dictionary, so you can use this information in your predicate.


# Example Plist 1 #

This plist contains one rule whose predicate says to install the update at
"Codebase" if the currently installed version is not version 1.1. This rule
may work for a product whose current version is 1.1 and all versions that are
not 1.1 should be "upgraded" to version 1.1.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
                       "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Rules</key>
  <array>
    <dict>
      <key>ProductID</key>
      <string>com.google.Foo</string>
      <key>Predicate</key>
      <string>Ticket.version != '1.1'</string>
      <key>Codebase</key>
      <string>https://www.google.com/engine/Foo.dmg</string>
      <key>Hash</key>
      <string>8O0cLNwuXQV79dMylImBvuSD9DY</string>
      <key>Size</key>
      <string>4443812</string>
    </dict>
  </array>
</dict>
</plist>
```

# Example Plist 2 #

This plist lists two rules for two different products (Foo and Bar). The
Foo product will only ever apply to Tiger machines because the predicate
looks for "SystemVersion.ProductVersion beginswith '10.4'". The Bar product
only targets Leopard systems because its predicate includes a similar check
for a system version beginning with '10.5'. The rest of this plist should be
pretty straight forward.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
                       "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Rules</key>
  <array>
    <dict>
      <key>ProductID</key>
      <string>com.google.Foo</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith '10.4' AND Ticket.version != '1.1'</string>
      <key>Codebase</key>
      <string>https://www.google.com/engine/Foo.dmg</string>
      <key>Hash</key>
      <string>somehash=</string>
      <key>Size</key>
      <string>328882</string>
    </dict>
    <dict>
      <key>ProductID</key>
      <string>com.google.Bar</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith '10.5' AND Ticket.version != '1.1'</string>
      <key>Codebase</key>
      <string>https://www.google.com/engine/Bar.dmg</string>
      <key>Hash</key>
      <string>YL8O0cuwVNXd7Q9lyBIMmvSD9DYu=</string>
      <key>Size</key>
      <string>228122</string>
    </dict>
  </array>
</dict>
</plist>
```


# Example Plist 3 #

This is the server response plist from [HelloEngine](http://code.google.com/hosting/redir?url=http%3A%2F%2Fcode.google.com%2Fp%2Fupdate-engine%2Fsource%2Fbrowse%2Ftrunk%2FSamples%2FHelloEngine%2FHelloEngine.m&t=018f69f17a5a84f4bd514d190165f008)

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Rules</key>
  <array>
    <dict>
      <key>ProductID</key>
      <string>com.google.HelloEngineTest</string>
      <key>Predicate</key>
      <string>Ticket.version != '2.0'</string>
      <key>Codebase</key>
      <string>file:///tmp/TestApp.dmg</string>
      <key>Size</key>
      <string>51051</string>
      <key>Hash</key>
      <string>L8O0cuNwVXQd79lMyBImvuSD9DY=</string>
    </dict>
  </array>
</dict>
</plist>
```
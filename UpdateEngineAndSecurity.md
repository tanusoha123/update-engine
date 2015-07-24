# Update Engine and Security #

Update Engine's goal with security is to let you do the simplest thing
in the most secure way possible.

## The Recommended Approach ##

We recommend that you use https (a.k.a. Secure HTTP, which uses SSL,
the Secure Sockets Layer) to retrieve your update plist.  By using
https, the server response is trusted.

Update Engine retrieves the server response from the URL listed in
your ticket.  When the server check happens via https you know the
response comes from a verified server, so you can trust it.

Update Engine uses the download URL in the server response.  At google
we have product downloads happen via http for performance
reasons. https is computationally expensive when you're serving a lot
of downloads.  But because you can trust the server response, you can
trust the hash and file size.

The hash and file size from the server response are used to verify the
download's integrity. The combination of SHA-1 hash and file size make
it a sufficiently difficult problem for a malicious disk image to be
created.  Update Engine will automaticaly verify the download with the
hash and file size.


## Alternatives ##

Unfortunately, https is not universally available.  Your host might
not support it, SSL certifications can be expensive, plus the added
overhead of configuring your webserver.

Update Engine actually does not impose any particular security model,
so you are free to use whatever security mechanism you feel is
appropriate.

For example, MacFUSE has shipped with an earlier version of Update Engine, called Keystone.  MacFUSE lives on code.google.com, which does not have https support.  To securely update McaFUSE, the team has added a server subclass which uses a public and private key to sign the server response plist.  This signature is verified once the server response has been downloaded.  You can see the code in
[the MacFUSE code browser](http://code.google.com/p/macfuse/source/browse/#svn/trunk/core/autoinstaller/KeystoneExtensions), in particular the SignedPlistServer class.  In MacFUSE's case the public key is compiled in to the code, but you could use a separate file with the key.

There are some caveats with this approach.  You have to be very
careful with your private key.  Since there is no public key
infrastructure involved, a key can't be revoked or changed once your
application has shipped.  If you lose your private key (natural
disaster, bad backups, insane employee) you won't be able to update
your app. What's worse is if the private key gets compromised an
attacker can use your update mechanism to install something bad.
Security is hard. (Let's go shopping.)

If you do decide to go with the key pair route, feel free to use
MacFUSE a guide.

## That's All Folks ##

To restate, our recommendation is to simply fetch your plist using
https. By using SSL, Update Engine will do proper certification
verification and avoid security issues.  You can trust the response,
so the SHA-1 hash can be trusted, so no reason to sign the download
itself. It's easy, and you don't have to reimplement any security
mechanisms.

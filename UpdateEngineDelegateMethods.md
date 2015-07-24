# Update Engine's Delegate Methods #

These are methods that a KSUpdateEngine delegate may implement.  There
are no required methods, and optional methods will have some reasonable
default action if not implemented.

The methods are listed in the relative order in which they're called.


```
- (void)engineStarted:(KSUpdateEngine *)engine
```

Called when Update Engine starts processing an update request.
if not implemented, the return value is `products`.


```
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldPrefetchProducts:(NSArray *)products
```

Sent to the delegate when product updates are available. The
`products` array is an array of NSDictionaries, each of with has keys defined
in KSServer.h. The delegate must return an array containing the product
dictionaries for the products which are to be prefetched (i.e., downloaded
before possibly prompting the user about the update). The two most common
return values for this delegate method are the following:

  * `nil` - Don't prefetch anything (same as empty array)
  * `products` - Prefetch all of the products (this is the default)


```
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldSilentlyUpdateProducts:(NSArray *)products
```

Sent to the delegate when product updates are available. The
`products` array is an array of KSUpdateInfos, each of with has keys
defined in KSUpdateInfo.h.  Much of the information in the
KSUpdateInfos comes from the ticket, configurable by your
PlistServerConfiguration file.  The delegate should return an array of
the products from the `products` list that should be installed
silently.

If not implemented, the return value is `products`.


```
- (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine
```

Returns a KSCommandRunner instance that can run commands on the delegates'
behalf. Update Engine may call this method multiple times to get a
KSCommandRunner for running Update Engine preinstall and
postinstall scripts. See EngineInstallScripts for more details on these scripts.

If not implemented, a KSTaskCommandRunner is created.



```
- (void)engine:(KSUpdateEngine *)engine
      starting:(KSUpdateInfo *)updateInfo
```

Sent by `engine` when the update as defined by `updateInfo` starts.


```
- (void)engine:(KSUpdateEngine *)engine
       running:(KSUpdateInfo *)updateInfo
      progress:(NSNumber *)progress
```

Sent by `engine` when we have progress for `updateInfo`.
`progress` is a float that specifies completeness, from 0.0 to 1.0.



```
- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot
```

Sent by `engine` when the update as defined by `updateInfo` has finished.
`wasSuccess` indicates whether the update was successful, and `wantsReboot`
indicates whether the update requested that the machine be rebooted.
Update Engine will not reboot the system for you.  That is the responsibility
of your application.


```
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldUpdateProducts:(NSArray *)products
```

Sent to the delegate when product updates are available. The
`products` array is an array of KSUpdateInfos, each of with has keys defined
in KSUpdateInfo.h. The delegate can use this list of products to optionally
display UI and ask the user what they want to install, or whatever. The
return value should be an array containing the product dictionaries that
should be updated. If a delegate simply wants to install all of the updates
they can trivially implement this method to immediately return the same
`products` array that they were given.

If not implemented, the return value is `products`.


```
- (void)engineFinished:(KSUpdateEngine *)engine wasSuccess:(BOOL)wasSuccess
```

Called when Update Engine is finished processing an update request.
`wasSuccess` indicates whether the update check was successful or not. An
update will fail if, for example, there is no network connection. It will **not**
fail if an update was downloaded and that update's installer happened to
fail.
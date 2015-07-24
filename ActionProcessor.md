# The Update Engine Action System #

Writing and comprehending sequential programs of the form `do_A()`,
then `do_B()`, then `do_C()` is generally very easy.  You can simply
look in one place in the source code and see exactly what's supposed
to be happening. It's clear that `do_C()` is run after `do_B()`, which
itself is run after `do_A()` completes. Even if we add a little logic
to the flow so that `do_C()` only runs if `do_B()` finished
successfully, it's generally pretty straightforward to understand.

You typically loose this simplicity and clarity when using
asynchronous tasks - there is typically no one place in the source
code that lists the 3 (in this example) tasks to be done. Furthermore,
you often need to come up with convoluted ways to have one task kick
off another task once it finishes. This can make the intent of the
program much more difficult to discern, in addition to making the code
less flexible. Nearly all of the tasks that Update Engine needs to
accomplish are asynchronous in nature (e.g., checking for updates,
downloading a file), so we knew this was a problem that needed to be
solved.

We solved this problem in Update Engine with what we call the Action
System. The action system is the mechanism by which Update Engine
accomplishes and manages all of its tasks, asynchronous or
not, in a simple and orderly manner. There are three primary abstractions
that make up the action system:

  * **KSAction** -- an abstract base class that defines a unit of work  (e.g., `KSDownloadAction`, `KSInstallAction`)
  * **KSActionProcessor** -- a queue of `KSAction` instances that will be run one at a time in the order they appear in the queue
  * **KSActionPipe** -- connects the "output" of one `KSAction` with the "input" of another; analogous to a typical Unix command-line pipe

Each task that Update Engine needs to perform is encapsulated as an
action, and that action is added to an action processor.  The action
processor is then responsible for running the action at the
appropriate time. Actions, that is, subclasses of KSAction, each
implement a `-performAction` method that the action processor calls
when it is time to run. Actions may run for as long as they need,
since they're asynchronous, but they must inform the action processor
when they are finished. Once an action finishes, the action processor
will start the next action in the queue, and so on, as shown here:
(actions are shown running from left to right)

![http://update-engine.googlecode.com/svn/site/action-processor-overview.png](http://update-engine.googlecode.com/svn/site/action-processor-overview.png)


Actions may communicate with one another using
`KSActionPipes`. `KSActionPipes` are analogous to typical Unix pipes,
except that `KSActionPipes` pass objects rather than using a simple
stream of bytes.  Pipes allow multiple actions to work together to
accomplish a greater task. For example, a task for downloading a file
(`KSDownloadAction`) may be combined with another action for
installing something from a disk image (`KSInstallAction`) to
accomplish the greater task of "updating a product"
(`KSUpdateAction`). This allows the intent of the code to be expressed
at the appropriate level of abstraction.


The action system allows Update Engine code to clearly express the
intent of otherwise very complex, asynchronous tasks. The following is
an actual snippet from the `KSUpdateEngine` class that shows how the
action system allowed us to very concisely express the essence of the
entire Update Engine framework.

```
- (void)triggerUpdateForTickets:(NSArray *)tickets {
  // Build a KSMultiAction pipeline with output flowing as indicated:
  //
  // KSCheckAction -> KSPrefetchAction -> KSSilentUpdateAction -> KSPromptAction

  KSAction *check    = [KSCheckAction actionWithTickets:tickets params:params_];
  KSAction *prefetch = [KSPrefetchAction actionWithEngine:self];
  KSAction *silent   = [KSSilentUpdateAction actionWithEngine:self];
  KSAction *prompt   = [KSPromptAction actionWithEngine:self];

  [KSActionPipe bondFrom:check to:prefetch];
  [KSActionPipe bondFrom:prefetch to:silent];
  [KSActionPipe bondFrom:silent to:prompt];

  [processor_ enqueueAction:check];
  [processor_ enqueueAction:prefetch];
  [processor_ enqueueAction:silent];
  [processor_ enqueueAction:prompt];

  [processor_ startProcessing];
}
```

It's not too difficult to see from this code that Update Engine first
checks for updates, then it may pre-download some things, then it may
silently install some updates, and finally it may ask the user if they
would like to install some additional updates. These are the four main
stages of a Update Engine update cycle. The action processor built in
the previous code snippet is shown here:

![http://update-engine.googlecode.com/svn/site/action-processor.png](http://update-engine.googlecode.com/svn/site/action-processor.png)


The first action to run is the Check action. Its input is an array of
tickets and its output is an array of dictionaries (`KSUpdateInfos`)
that each represent one available update. All of the actions in this
queue communicate with one another by emitting an array of
`KSUpdateInfo` dictionaries, allowing allowing a uniform I/O interface
on each of these actions. Now for a closer look at each of these
high-level actions in more detail.


## The "Check" Action ##

The `KSCheckAction` class takes the array of tickets from its input,
groups them by the server they need to talk to, and then creates one
`KSUpdateCheckAction` for each server back-end that needs to be
contacted. It will then run all of these subactions using its own,
internal, action processor. The `KSCheckAction` itself is not finished
until all of its subactions are finished. Once that happens,
`KSCheckAction`'s output is the aggregate of all of its subactions'
output, as shown here:

![http://update-engine.googlecode.com/svn/site/action-processor-check.png](http://update-engine.googlecode.com/svn/site/action-processor-check.png)


The KSUpdateCheck subactions will communicate with server
backends to determine what software (if any) needs to be
updated. However, we wanted to keep the design flexible enough so that we
could change back-ends.  For example, Update Engine ships with KSPlistServer,
which is a different server protocol than what is used internally at Google.
Update Engine users are also welcome to write their own server subclasses
to satisfy their individual needs.

`KSCheckActions` use two primary abstractions when dealing with
server backends: `KSServer` and `KSUpdateCheckAction`. `KSServer` is an
abstract base class whose subclasses encapsulate all of the knowledge
about a specific instance of a "Update Engine back-end
server". Concrete instances of this class will contain all of the
knowledge specific to a particular type of server, as well as a URL
identifying a particular instance of the server. This class will
handle creating `NSURLRequest` objects from an array of `KSTicket`
objects. Similarly, it will handle creating `KSUpdateInfo` dictionary
instances from the server's response.

The `KSUpdateCheckAction` class is a concrete `KSAction` subclass. The objects
must be created with a `KSServer` instance and an array of `KSTickets`,
and it will then handle the HTTP(S) communication with the server, and
coordinate with the given `KSServer` instance to create
`KSUpdateActions` from the server's response. The `KSUpdateCheckAction`
will do HTTP(S) communication using `GDataHTTPFetcher`, so it will
automatically have back off and retry logic.


## The Prefetch Action ##

The `KSPrefetchAction` class takes as input the array of `KSUpdateInfo`
dictionaries from `KSCheckAction`'s output. The prefetch action
sends a message to the Update Engine's delegate and asks which of
the updates should be downloaded immediately. Based on the response
from the delegate, `KSPrefetchAction` will create one
`KSDownloadAction` for each update to be prefetched, and it will run
them on its own internal action processor in the same way that
`KSCheckAction` did previously. The output of `KSPrefetchAction` is
always the same as its input, whether or not anything was actually
downloaded.  The act of downloading doesn't change the set of files that
need updating.

`KSDownloadAction` is responsible for downloading all files. It
downloads files by `NSTask`'ing a separate "`ksurl`" process to do the
actual work. "`ksurl`" (like "`curl`") is a small command-line tool that
simply uses Foundation's `NSURLDownload` to download a
file. KSDownloadAction does this in a separate process as a security
measure to ensure that downloads (a network transaction) never happen
as root. Once downloaded, `KSDownloadAction` will verify that the
downloaded file matches a known size and pre-computed SHA-1 hash to
guarantee the downloaded file is intact and wasn't tampered with.


## The Silent Update Action ##

`KSSilentUpdateAction` objects take as input the array of `KSUpdateInfo`
dictionaries that were the output of the `KSPrefetchAction`. It then
sends a message to the Update Engine's delegate asking which of the
updates should be immediately installed silently. Depending on the
delegate's response, some number of `KSUpdateActions` will be created
to install the requested updates.

KSUpdateAction itself is a "composite" action,  following the
Composite design pattern, made up of a `KSDownloadAction` and
a `KSInstallAction`. If the update to be installed was previously
downloaded in the prefetch stage, then this download action will find
the download cached and the action will complete immediately. Otherwise
if the update was not prefetched, the download will happen at this
point. Either way, once this download completes, the `KSInstallAction`
will handle installing the downloaded update by running the scripts
on the disk image.


## The Prompt Update Action ##

The last stage of our main action processor's pipeline is the
`KSPromptAction`. This action is almost identical to the
`KSSilentUpdateAction` with the only difference being the callback that
it sends to the Update Engine's delegate. This difference is
necessary so that we can separate updates that require user permission
and updates that do not. `KSPromptAction` and `KSSilentUpdateAction` are both
subclasses of the `KSMultiUpdateAction` abstract base class.

The following diagram shows the hierarchy of all of the actions that
we've discussed so far. Note that actions are processed from left to
right.

![http://update-engine.googlecode.com/svn/site/action-processor-complete.png](http://update-engine.googlecode.com/svn/site/action-processor-complete.png)


# Writing Your Own Actions #

You're not limited to the action subclasses provided by Update Engine.
You're welcome to create your own `KSAction` subclasses and operate your
own `KSActonProcessors`.

Update Engine includes the "Actions" sample which uses `KSAction` subclasses
for downloading a set of image files and displays them in an `NSTableView`, so
you can see some custom actions in action.

## Subclassing KSAction ##

There's only two things you must do when subclassing `KSAction`: perform the
action, and then let the action processor know when you've finished.


### Perform Action ###

The first thing to do is override `-performAction`.  This is where you perform
your work, whether it's something asynchronous like fetching
something over the internet:

```
- (void)performAction {
  // Kick off an HTTP fetch for the catalog.
  NSURLRequest *request = [NSURLRequest requestWithURL:catalogURL_];
  httpFetcher_ = [[GDataHTTPFetcher alloc] initWithRequest:request];
  [httpFetcher_ beginFetchWithDelegate:self
                     didFinishSelector:@selector(fetcher:epicWinWithData:)
                       didFailSelector:@selector(fetcher:epicFailWithError:)];

}  // performAction
```

or performing a synchronous processing action:

```
- (void)performAction {
  // Pick up the array of url strings from the previous stage in the pipeline.
  NSArray *imageURLStrings = [[self inPipe] contents];

  // If we have a predicte, filter the incoming array.
  NSArray *filteredURLStrings;
  if (filterPredicate_) {
    filteredURLStrings =
      [imageURLStrings filteredArrayUsingPredicate:filterPredicate_];
  } else {
    filteredURLStrings = imageURLStrings;
  }

  // Send the results to the next action in the chain.
  [[self outPipe] setContents:filteredURLStrings];

  // All done!
  [[self processor] finishedProcessing:self successfully:YES];

}  // performAction
```

### Finished Processing ###

You need to tell the action processor when you've completed your action
by calling `-finishedProcessing:successfully:`

```
[[self processor] finishedProcessing:self successfully:YES];
```

This tells the action processor that it is time to move on to the next action.


## Using Pipes ##

Recall that `KSActionPipe` is used to connect actions to each other.
Before you add actions connected by a pipe to an action processor, you
need to hook up the pipe:

```
  UECatalogLoaderAction *catalogLoader = ...;
  UECatalogFilterAction *filter = ...;

  [KSActionPipe bondFrom:catalogLoader to:filter];
```

Then, in your first action subclass (the catalogLoader in this case), before
you tell your action processor that you have `-finishedProcessing:`, you
put the object into the pipe that you want the other action to find:

```
  [[self outPipe] setContents:urlStrings];
```

In your second action subclass (the filter in this case), you read
from the pipe in your `-performAction` :

```
  NSArray *imageURLStrings = [[self inPipe] contents];
```


# Why not NSOperation? #

One good question is "why not use `NSOperation` for this stuff."
`NSOperation` can be used for much of what the action processor does.

The main reason is that Update Engine needs to support Tiger (Mac OS X 10.4).
`NSOperation` and friends are 10.5 and later.

`NSOperation`s don't have a pipe concept.  We would need to add that on top of
`NSOperations`.  Not difficult, but would be extra work.  The operations are
executed sequentially, so it would be a little extra work to set up the
proper operation dependencies before adding them to the operation queue.

The last reason is that that the action processor does not need to use
a new thread for its operations since the majority of the work done is
either network-related (asynchronous, runloop based), or very fast (like the
"Actions" sample image URL filter).  To get non-threaded operations,
we would need to use "concurrent" `NSOperations` for this, which are
awkward to implement, and we would need to implement the operation's
KVO notifications when the operations change state.

# Testing and Code Coverage #

We strive to write some of the best code here at Google, and to prove
that it really is as good as we think we need to make sure it's very well
tested. To make sure it can be very well tested, we need to design our
code to be testable from the beginning. Code that is not designed to
be testable is rarely easy to test, whether you're talking about
unit tests, system tests, or even manual testing.

The Update Engine engineering team is very proud of the level of unit
testing and test coverage that we've achieved.  Every source file in
`Common` and `Core` has a corresponding unit test.


## Designing Testable Code ##

Designing code to be testable is extremely important and has a number
of benefits:

  * It's easier to unit test the code and find bugs before users (or even your coworkers) do
  * The developer of a piece of code can use the code as a client, which can improve the code's API.  If it's awkward to use in a test, it'll be awkward to use in real life.
  * Testable code tends to be more modular
  * Testable code tends to be more flexible

Only one of these benefits is about finding bugs. The remaining points
are all about improving the code.  We feel that the majority of the
benefit of unit testing (also known as "developer testing") is about
producing all-around higher quality code.


### Write Object-Oriented Code ###

Writing object-oriented code may be an obvious point, but
it's one one that's important and can be easily
overlooked. Writing object-oriented code is more than just using the
`@interface` keyword, or using the term "method".

Fundamentally, object-oriented code
is made up of a number of separate objects that interact with each
other through their interfaces to accomplish a given task. Simply
wrapping a handful of C functions in a class definition is not object
oriented.

Well-written object-oriented programs look and feel very different
from their functional or procedural counterparts. Object-oriented code
demands an object-oriented mindset just like functional programming
demands a functional mindset. Be sure to think of your problem space
in terms of objects, not functions. Design the solution to your
problem in terms of objects and their interactions, nouns and verbs,
and not functions and their arguments.

Classes describe objects, objects represent things, and things do stuff.
Useful things typically have useful interfaces. Make sure you clearly
understand the object model for your program before attempting to
codify it in class implementations. Think about how the objects in
your model will interact and let this information help drive the
objects' interfaces.

Carefully create your class's interface. A class filled with a bunch
of no-arg functions that return void are generally not very
useful. This is also a sign of a weak object concept, or an attempt to
cram a functional program into a class to make it appear object
oriented.

Similarly, classes with few to no methods in the public interface
indicate a class that is just one big implementation detail. This
class will be difficult to work with, extend, test, and
re-use. Classes like this look like functional code wearing an
unconvincing OO costume.


### Naming ###

The names of the classes, objects, variables, methods, and functions
in your program creates a vocabulary that describes
your program to the compiler and other engineers. These words
should be very carefully chosen so that your program reads well and
clearly shows its intent. Imagine a novelist or a poet struggling over
word choice. We as developers should invest the same kind of effort
on our names. The compiler doesn't care  but your
peers will. As will you when you reread the code a year or two later.

Classes should have a specific purpose and should have concise,
descriptive names. Generic names like "Controller", "Manager", and
"App" tend to be so vague that everything really "fits", which lends
itself to kitchen sink syndrome. You should be able to describe the
essence of a class in one sentence. If you can't clearly and concisely
describe what a class is or what it does, it represents a poorly
defined concept. Go back to the drawing board and refactor this
class/concept before it infects other parts of your code.
Take some more time to think about the problem, grab a cup of
coffee, clarify the concept you're trying to model, have a snack,
and a good name will reveal itself.

Perhaps the object you had trouble naming should really be broken up
into two separate classes, each with a very descriptive name and
purpose. Your code will end up being much clearer and easier to
maintain, and you'll be glad you waited.

If at any point you think of a better name for an existing
class/method/variable, rename it. There is no reason to continue using
a poorly named object if you know of a better name. Xcode includes a
Refactoring command that will do project wide renamings.  There is also
a command-line utility called `tops` that let you do similar things on
a more localized basis.


## Use Dependency Injection ##

Dependency Injection is awesome and easy.  It can help you write
more loosely coupled code that is much easier to test.

Rather than an object taking responsibility for acquiring some
resources, Dependency Injection says to make that resource a property
of the object instead.  OK, so what does that actually mean?

Take a look at
[KSUpdateCheckAction](http://code.google.com/p/update-engine/source/browse/trunk/Core/KSUpdateCheckAction.h).  This is an action class that checks for updates
using a KSServer to do the actual server communications.  We could have
designed KSUpdateCheckAction to use a default server, or to query some
kind of Abstract Server Factory to acquire a global server object.

Instead, the server is an argument to the class creation and init methods:

```
+ (id)checkerWithServer:(KSServer *)server tickets:(NSArray *)tickets;
- (id)initWithServer:(KSServer *)server tickets:(NSArray *)tickets;
```

This allows
[KSUpdateCheckActionTest](http://code.google.com/p/update-engine/source/browse/trunk/Core/KSUpdateCheckActionTest.m) to create special severers that assist
in testing.  The tests can just create a custom server object, and then
create a new update check action with that new server.

Similarly,
[KSMockFetcherFactory](http://code.google.com/p/update-engine/source/browse/trunk/Core/KSMockFetcherFactory.h) is a testing class that let us provide mock
factories with special behaviors, such as providing a fetcher that always fails
with error, or will supply a given NSData to other objects in the system.

Tests that require a connected network or a database server are
frequently a big problem.  Network and database operations are usually
slow.  Slow tests bog down your entire develop / test / debug / curse
cycle.  Plus they can make your tests break for reasons completely
unrelated to the code being tested: The database may be down.  The cat may
have unplugged the Time Capsule.  Using dependency injection for the
networking and database classes can let you supply simpler test
objects that will exercise all the dark corners of your class without
pulling in a lot extra complexity.

Oh by the way, one simple, but surprisingly non-obvious thing, is
using file:// URLs with APIs that take URLs.  file:// URLs let you put
test data into a class without requiring a live network connection or
running a web server somewhere.


## Use Good Object-Oriented Design Patterns ##

You might have seen the term "GoF" before.  It stands for _[Gang of Four](http://en.wikipedia.org/wiki/Gang_of_Four_(software))_,
referring to the four authors of the quintessential book
[Design Patterns](http://www.amazon.com/Design-Patterns-Object-Oriented-Addison-Wesley-Professional/dp/0201633612).
Even though the book is somewhat dated, and should not be followed
religiously (amen), you should certainly have a
copy or have easy access to one. The ideas and terminology presented
in the book are important and should be understood by all software
engineers who write object oriented code. Some of the discussed
patterns are certainly more common than others. Don't worry about
memorizing the details of all of them. Just be familiar with them, and
know where you can look to find the details when necessary.

Beyond the GoF's 1994 magnum opus, there are a number of other
"patterns" that can be very useful. Formal refactoring techniques, as
described by Martin Fowler in his
[Refactoring](http://www.amazon.com/exec/obidos/ASIN/0201485672) book, can help you
improve the design of existing code.

Before you can refactor, you must know when to refactor code. Sometimes
refactoring is needed almost on a daily or weekly basis. Some of the
big signs that you need to stop, think, and refactor your code are
when

  * You and your co-workers curse a certain piece of code daily
  * A method, function, or class is getting too big or complicated to understand or to change
  * A class has too many responsibilities
  * Classes are too closely coupled
  * An object is "too difficult" to test

Strive for very loosely coupled classes. Understand the
[Liskov substitution principle](http://en.wikipedia.org/wiki/Liskov_substitution_principle), the
[Law of Demeter](http://en.wikipedia.org/wiki/Law_of_Demeter), and the
[Open/closed principle](http://en.wikipedia.org/wiki/Open/closed_principle).
Learn when to apply
refactorings and patterns, and when not to. Know the names of
refactorings and patterns so that you can more easily communicate with
your fellow engineers. Lots of new ideas in software engineering like
Agile Development, Test-Driven Development, and eXtreme Programming
have deep roots in topics like OO design patterns and refactorings.

Know when and how to properly subclass. Subclass when you're defining
a new type that truly "**is a**" refinement of the parent class's
type. Do not subclass simply as a way to reuse code. Subclasses have a
very intimate relationship with their parent class, which can lead to
unwanted dependencies and relying on hidden assumptions. In general, prefer
composition ("has a") to inheritance ("is a").


### Singletons Considered Harmful ###

Also, keep in mind that the Singleton pattern is often overused and
has become a kind of antipattern. If you can accomplish your goal
without using a singleton, do it. Never use a singleton simply because
you want global access to an object.
[Fear the Singleton](http://unixjunkie.blogspot.com/2006/07/singleton-smell_25.html) just like you would fear any global variable.

Singletons are hard to test because they are a global resource.  One
test can mess up the Singleton's state for the next test.  It can also be
hard to get to the underlying functionality of a singleton to test it.
It's ok to have a class method to give global semantics to something, such
as NSUserDefaults' +standardUserDefaults, but go ahead and allow multiple
instances of the class to be created, manipulated, and destroyed.  If for
no other reason to allow for better testability.


## Prefer Instance Methods to Class Methods ##

It's not uncommon to see utility classes that are full of class
methods and no instance methods. In this case, the class is merely
defining a namespace, or scope, in which to group these hopefully
related methods (in reality they're actually just "functions"). This
is generally not a good idea for a number of reasons:

  * Class methods can be more difficult to mock and for subclasses to override properly
  * Class methods can make dependency injection more difficult
  * Class utility methods may indicate a design flaw in your object model
  * Class methods do not play well if you need to maintain state

Even if your class currently does not have any of these
problems, don't forget that you still need to think about the
future. Will the class ever need to maintain state, say by adding a cache?
Will anyone ever want to "inject" an instance of your
class for testing? Thankfully, there is a wonderful alternative to
class methods -- instance methods!

Instance methods solve all of the problems with class methods, except
for one: instance methods are slightly longer to type because you need
to get an instance of the object first. However, with advanced IDEs
like Xcode that have code completion, this is really not a
problem. It's much better to prefer instance methods to class
methods. Notice that Apple rarely uses class methods for utility
classes either.  Take a look at NSProcessInfo, NSFileManager, and NSWorkspace.

And for those who are curious what a good use of class methods is,
it's convenience creation methods like NSString' +stringWithFormat:.

Also note that Objective-C classes cannot have static methods -- they
have class methods. The difference is that class methods are
dynamically bound at runtime, whereas static methods are bound at
compile time. In other words, Objective-C class methods can be
overridden by subclasses. However, class methods do not have access to
any storage other than static variables. This overlap of dynamically
bound class methods and static storage can cause bizarre problems that
are no fun to debug. Do not use class methods if you need to maintain
state. Again, instance methods are better in almost every way.


# Update Engine, Testing, and Code Coverage #

The Update Engine Xcode project is already set up to generate coverage when
the tests are run in Debug mode.  To see the coverage for Update Engine,
build and run the "Test All" target.  Once it's finished doing its thing,
drag and drop your `build` directory on top of
[CoverStory](http://code.google.com/p/coverstory/).

To filter out the Google Toolbox for Mac source files, which we don't
completely exercise in our tests, enter `/update-engine/C` in the search box
at the bottom of the CoverStory window.

![http://update-engine.googlecode.com/svn/site/coverage.png](http://update-engine.googlecode.com/svn/site/coverage.png)
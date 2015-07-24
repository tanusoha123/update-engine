![http://update-engine.googlecode.com/svn/site/update-engine-small.gif](http://update-engine.googlecode.com/svn/site/update-engine-small.gif)

Update Engine is a flexible Mac OS X framework that can help developers keep their products up-to-date. It can update nearly any type of software, including Cocoa apps, screen savers, and preference panes. It can even update kernel extensions, regular files, and root-owned applications. Update Engine can even update multiple products just as easily as it can update one.

Google ships many different pieces of Mac software ranging from simple Cocoa applications to complicated software systems. We needed a robust software update solution that would be able to update all of our current and future Mac products. And we designed and built Update Engine to solve this problem.

The following are some unique features of Update Engine:

  * Can update virtually any type of product (e.g., Cocoa app, pref pane, kernel extension)
  * Can update non-bundle-based products (e.g., command-line tool, plain file)
  * Can update many products at once
  * Solid framework on which to build

We have two movies for you to watch.

The first is by Greg and it gives you and overview of Update Engine, why we built it, and what makes it tick.  In short, HowDoesUpdateEngineWork. **IMPORTANT:** this demo uses "http:" URLs in the example _tickets_ to save space. To keep things secure in the real world, **https:** URLs should be preferred when fetching the plist from the server. See UpdateEngineAndSecurity for more details.

[![](http://update-engine.googlecode.com/svn/site/overviewPoster.png)](http://www.youtube.com/watch?v=9K_W5Af99PU)

The second is by Mark and it walks you through running the [HelloEngine](http://code.google.com/p/update-engine/source/browse/trunk/Samples/HelloEngine/HelloEngine.m) sample program.

[![](http://update-engine.googlecode.com/svn/site/helloEnginePoster.png)](http://www.youtube.com/watch?v=x2m_poXQYMY)


To browse the Update Engine source code, visit the [Source tab](http://code.google.com/p/update-engine/source).  Changes to Update Engine are documented in the [release notes](http://code.google.com/p/update-engine/source/browse/trunk/ReleaseNotes.txt).


If you find a problem/bug or want a new feature to be included in Update Engine, please join the [discussion group](http://groups.google.com/group/update-engine) or submit an [issue](http://code.google.com/p/update-engine/issues/list).

Update Engine follows the [Google Objective-C Style Guide](http://google-styleguide.googlecode.com/svn/trunk/objcguide.xml).


---


The Update Engine developers believe in TestingAndCoverage, with a goal to maintain 90% or better code coverage at all times.  Our first release has 97.4% coverage.

![http://chart.apis.google.com/chart?cht=p3&chd=t:97.4,2.6&chs=325x100&chl=Covered|To%20Be%20Covered&bork=fnord.png](http://chart.apis.google.com/chart?cht=p3&chd=t:97.4,2.6&chs=325x100&chl=Covered|To%20Be%20Covered&bork=fnord.png)
// Copyright 2009 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <SenTestingKit/SenTestingKit.h>
#import "KSTicketTestBase.h"
#import "KSOmahaServer.h"
#import "KSUpdateInfo.h"
#import "KSUpdateEngineParameters.h"
#import "KSStatsCollection.h"
#import "KSFrameworkStats.h"

#define DEFAULT_BRAND_CODE @"GGLG"


@interface KSOmahaServer (TestingFriends)
- (BOOL)isProductActive:(NSString *)productID;
- (BOOL)isAllowedURL:(NSURL *)url;
@end

@interface KSOmahaServerTest : KSTicketTestBase
// helper to xpath things and verify they exist.  If only one item is found,
// return it.  Else return the array of items.
- (id)findInDoc:(NSXMLDocument *)doc path:(NSString *)path count:(int)count;
// If possible, convert a server request into an XMLDocument.
- (NSXMLDocument *)documentFromRequest:(NSData *)request;
@end


/* Sample request:

<?xml version="1.0" encoding="UTF-8"?>
<o:gupdate xmlns:o="http://www.google.com/update2/request" version="UpdateEngine-0.1.2.0" protocol="2.0" machineid="{DE30B8C3-2A20-356F-841A-A1D80FE18D02}" ismachine="0" userid="{97E88974-7CB2-4831-ABC8-0776C7BEAB6B}">
    <o:os version="MacOS" sp="10.5.2"></o:os>
    <o:app appid="com.google.UpdateEngine" version="0.1.3.237" lang="en-us" brand="GGLG" installage="37" tag="f00bage">
        <o:updatecheck></o:updatecheck>
        <o:ping active="0"></o:ping>
    </o:app>
    <o:app appid="com.google.Matchbook.App" version="0.1.1.0" lang="en-us" brand="GGLG" installage="23">
        <o:updatecheck></o:updatecheck>
        <o:ping active="0"></o:ping>
    </o:app>
    <o:app appid="com.google.Something.Else" version="0.1.1.0" lang="en-us" brand="GGLG" installage="0">
        <o:updatecheck tttoken="seCRETtoken"/>
        <o:ping active="1"></o:ping>
    </o:app>
</o:gupdate>


Sample response (but not for the above request):

<?xml version="1.0" encoding="UTF-8"?>
<gupdate xmlns="http://www.google.com/update2/response" protocol="2.0">
    <app appid="{8A69D345-D564-463C-AFF1-A69D9E530F96}" status="ok">
        <updatecheck codebase="http://tools.google.com/omaha_download/test.dmg" hash="vaQXjdS1P6VP31rkqe8YuzbNzvk=" needsadmin="true" size="5910016" status="ok"></updatecheck>
        <rlz status="ok"></rlz>
        <ping status="ok"></ping>
    </app>
</gupdate>
*/

@implementation KSOmahaServerTest

- (id)findInDoc:(NSXMLDocument *)doc path:(NSString *)path count:(int)count {
  NSError *err = nil;
  NSArray *nodes = [doc nodesForXPath:path error:&err];
  STAssertNotNil(nodes, nil);
  STAssertNil(err, nil);
  STAssertTrue([nodes count] == count, nil);
  if ([nodes count] == 1) {
    return [nodes objectAtIndex:0];
  } else {
    return nodes;
  }
}

- (NSXMLDocument *)documentFromRequest:(NSData *)request {
  // sanity check
  NSString *requestString = [[[NSString alloc] initWithData:request
                                               encoding:NSUTF8StringEncoding]
                              autorelease];
  STAssertTrue([requestString rangeOfString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"].location == 0, nil);
  NSError *error = nil;
  // now make a doc.
  NSXMLDocument *doc = [[[NSXMLDocument alloc]
                          initWithData:request
                          options:0
                          error:&error]
                         autorelease];
  STAssertNil(error, nil);
  STAssertNotNil(doc, nil);
  return doc;
}

// The goal here is to look for some items like the server would.
// I don't verify values because some will surely change (e.g. version)
- (void)findCommonItemsInDocument:(NSXMLDocument *)doc
                         appcount:(int)appcount
                     tttokenCount:(int)tttokenCount {
  [self findInDoc:doc path:@".//o:gupdate/@version" count:1];
  [self findInDoc:doc path:@".//o:gupdate/@protocol" count:1];
  [self findInDoc:doc path:@".//o:gupdate/@machineid" count:1];
  [self findInDoc:doc path:@".//o:gupdate/@ismachine" count:1];
  [self findInDoc:doc path:@".//o:gupdate/@userid" count:1];
  [self findInDoc:doc path:@".//o:gupdate/o:os/@version" count:1];
  [self findInDoc:doc path:@".//o:gupdate/o:os/@sp" count:1];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@appid" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@version" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@brand" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@installage" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/o:updatecheck" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/o:updatecheck/@tttoken"
            count:tttokenCount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/o:ping/@active" count:appcount];
}

- (void)testCreation {
  NSArray *goodURLs =
    [NSArray arrayWithObjects:
     [NSURL URLWithString:@"https://blah.google.com"],
     [NSURL URLWithString:@"https://blah.google.com/foo/bar"],
     [NSURL URLWithString:@"https://blah.google.com"],
     [NSURL URLWithString:@"https://foo.blah.google.com"],
     [NSURL URLWithString:@"https://foo.bar.blah.google.com"],
     nil];

  NSArray *badURLs =
    [NSArray arrayWithObjects:
     [NSURL URLWithString:@"file:///tmp/oop/ack"],
     [NSURL URLWithString:@"http://www.google.com/foo/bar"],
     [NSURL URLWithString:@"http://google.com"],
     [NSURL URLWithString:@"http://foo.google.com"],
     [NSURL URLWithString:@"https://elvisgoogle.com"],
     [NSURL URLWithString:@"https://www.gooogle.com"],
     [NSURL URLWithString:@"https://foo.com"],
     [NSURL URLWithString:@"https://google.foo.com"],
     nil];

  NSArray *allowedSubdomains = [NSArray arrayWithObject:@".blah.google.com"];
  NSDictionary *params =
    [NSDictionary dictionaryWithObject:allowedSubdomains
                                forKey:kUpdateEngineAllowedSubdomains];
  NSURL *url = nil;
  NSEnumerator *urlEnumerator = nil;

  urlEnumerator = [goodURLs objectEnumerator];
  while ((url = [urlEnumerator nextObject])) {
    STAssertNotNil([KSOmahaServer serverWithURL:url params:params], nil);
  }

  // In DEBUG builds, make sure the bad URLs show up as "good" (i.e., not nil),
  // but in Release builds, the bad URLs should show up as "bad" (i.e., nil).
  urlEnumerator = [badURLs objectEnumerator];
  while ((url = [urlEnumerator nextObject])) {
#ifdef DEBUG
    STAssertNotNil([KSOmahaServer serverWithURL:url params:params], nil);
#else
    STAssertNil([KSOmahaServer serverWithURL:url params:params], nil);
#endif
  }
}

- (void)testSingleTicket {
  // one file ticket
  NSMutableArray *oneTicket = [NSMutableArray arrayWithCapacity:1];
  [oneTicket addObject:[httpTickets_ objectAtIndex:0]];
  NSArray *requests = [httpServer_ requestsForTickets:oneTicket];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  // make sure we find 1 app
  [self findInDoc:doc path:@".//o:gupdate/o:app" count:1];
  NSXMLNode *n = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid" count:1];
  STAssertTrue([n isKindOfClass:[NSXMLNode class]], nil);
  STAssertTrue([[n stringValue] isEqualToString:[[oneTicket objectAtIndex:0]
                                                  productID]], nil);
  // basic check of a request
  [self findCommonItemsInDocument:doc appcount:1 tttokenCount:0];
}

- (void)testSeveralTickets {
  // (try to) send all 3 http tickets to the http server
  NSArray *requests = [httpServer_ requestsForTickets:httpTickets_];
  int ticketcount = [httpTickets_ count];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  NSArray *apps = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid"
                        count:ticketcount];
  STAssertNotNil(apps, nil);
  STAssertTrue([apps isKindOfClass:[NSArray class]], nil);
  STAssertTrue([apps count] == ticketcount, nil);
  int x;
  for (x = 0; x < ticketcount; x++) {
    STAssertTrue([[apps objectAtIndex:x] isKindOfClass:[NSXMLNode class]], nil);
  }
  // make sure we find all 3 apps in there
  for (x = 0; x < ticketcount; x++) {
    NSString *appToFind = [[httpTickets_ objectAtIndex:x] productID];
    BOOL found = NO;
    NSEnumerator *aenum = [apps objectEnumerator];
    id app = nil;
    while ((app = [aenum nextObject])) {
      if ([[app stringValue] isEqualToString:appToFind]) {
        found = YES;
        break;
      }
    }
    STAssertTrue(found == YES, nil);
  }
  // basic check of a request
  [self findCommonItemsInDocument:doc appcount:ticketcount tttokenCount:0];
}

- (void)testTTTokenInTicket {
  // 4 tickets, but only 2 have tttokens
  int size = 4;
  NSMutableArray *lottatickets = [NSMutableArray arrayWithCapacity:size];
  for (int x = 0; x < size; x++) {
    if (x % 2) {
      [lottatickets addObject:[self ticketWithURL:httpURL_ count:x]];
    } else {
      NSString *token = [NSString stringWithFormat:@"token-%d", x];
      [lottatickets addObject:[self ticketWithURL:httpURL_ count:x
                                          tttoken:token]];
    }
  }
  STAssertTrue([lottatickets count] == size, nil);
  NSArray *requests = [httpServer_ requestsForTickets:lottatickets];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  // make sure the request has 4 of these:
  //  <o:app appid="{guid...}" ... > </o:app>
  NSArray *apps = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid"
                        count:size];
  STAssertNotNil(apps, nil);
  STAssertTrue([apps isKindOfClass:[NSArray class]], nil);
  STAssertTrue([apps count] == size, nil);

  // Make sure it only has 2 tttokens
  [self findCommonItemsInDocument:doc appcount:size
                     tttokenCount:(size >> 1)];
}

- (void)testAWholeLottaTickets {
  int size = 257;
  NSMutableArray *lottatickets = [NSMutableArray arrayWithCapacity:size];
  for (int x = 0; x < size; x++) {
    [lottatickets addObject:[self ticketWithURL:httpURL_ count:x]];
  }
  STAssertTrue([lottatickets count] == size, nil);
  NSArray *requests = [httpServer_ requestsForTickets:lottatickets];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  // make sure the request has 257 of these:
  //  <o:app appid="{guid...}" ... > </o:app>
  NSArray *apps = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid"
                        count:size];
  STAssertNotNil(apps, nil);
  STAssertTrue([apps isKindOfClass:[NSArray class]], nil);
  STAssertTrue([apps count] == size, nil);
}

- (void)testBadTickets {
  // no tickets --> no request!
  NSMutableArray *empty = [NSMutableArray array];
  STAssertNil([httpServer_ requestsForTickets:empty], nil);

  // send a file ticket to an http server
  NSMutableArray *oneFileTicket = [NSMutableArray arrayWithCapacity:1];
  [oneFileTicket addObject:[fileTickets_ objectAtIndex:1]];
  STAssertNil([httpServer_ requestsForTickets:oneFileTicket], nil);
}

static char *kBadResponseStrings[] = {
  "",  // empty
  "                                       ", // whitespace
  "blah blah", // bogus
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",  // bare minimum XML document
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> </gupdate>", // empty
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\">", // malformed XML (no terminating gupdate)
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\"></app> </gupdate>",  // incomplete
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\" status=\"ko\"></app> </gupdate>",  // bad status
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\" status=\"ok\"></app> </gupdate>",  // good status, no updatecheck node
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app status=\"ok\"><updatecheck codebase=\"\" hash=\"\" needsadmin=\"\" size=\"\" status=\"ok\"></updatecheck> </app> </gupdate>",  // updatecheck, no appid
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\" status=\"ok\"><updatecheck hash=\"\" needsadmin=\"\" size=\"\" status=\"ok\"></updatecheck> </app> </gupdate>",  // updatecheck, missing a required attribute for updatecheck
};

// KSOmahaServer ignores its first arg (a NSURLResponse).
- (void)testBadResponses {
  NSArray *results = nil;
  results = [httpServer_ updateInfosForResponse:nil data:nil];
  STAssertTrue([results count] == 0, nil);

  int strings = sizeof(kBadResponseStrings)/sizeof(char *);
  for (int x = 0; x < strings; x++) {
    NSData *data = [NSData dataWithBytes:kBadResponseStrings[x]
                                  length:strlen(kBadResponseStrings[x])];
    STAssertNotNil(data, nil);
    results = [httpServer_ updateInfosForResponse:nil data:data];
    STAssertTrue([results count] == 0, nil);
  }
}

- (void)testBadPrettyprint {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  NSData *data = [@"hargleblargle" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *prettyInPink = [server prettyPrintResponse:nil data:data];
  STAssertNil(prettyInPink, nil);
}

- (NSArray *)updateInfoForStr:(const char *)str {
  NSData *data = [NSData dataWithBytes:str length:strlen(str)];
  return [httpServer_ updateInfosForResponse:nil data:data];
}

static char *kSingleResponseString =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"    <app appid=\"{8A69D345-D564-463C-AFF1-A69D9E530F96}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test.dmg\" hash=\"vaQXjdS1P6VP31rkqe8YuzbNzvk=\" needsadmin=\"true\" size=\"5910016\" status=\"ok\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"</gupdate>";

- (void)testSingleResponse {
  NSArray *updateInfos = [self updateInfoForStr:kSingleResponseString];
  STAssertEquals([updateInfos count], 1U, nil);
}

// Notice that the second app in this list has prompt="true" and
// requireReboot="true" set, and the second app has a localization
// expansion for the moreinfo URL, a localization bundle path,
// a display version, and a pony.
static char *kMultiResponseString =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"    <app appid=\"{26EA52A6-C1F2-11DB-B91C-B0B155D89593}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test2.dmg\" hash=\"hcqiyPD01sWXVdYHNpWe4H2OBak=\" needsadmin=\"false\" size=\"1868800\" status=\"ok\" MoreInfo=\"http://google.com\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"    <app appid=\"{8A69D345-D564-463C-AFF1-A69D9E530F96}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test.dmg\" hash=\"vaQXjdS1P6VP31rkqe8YuzbNzvk=\" needsadmin=\"true\" size=\"5910016\" status=\"ok\" Prompt=\"true\" RequireReboot=\"true\" MoreInfo=\"http://desktop.google.com/mac/${hl}/foobage.html\" LocalizationBundle=\"/Hassel/Hoff\" DisplayVersion=\"3.1.4\" Version=\"3.1.4 (lolcat)\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"</gupdate>";

static char *kMegaResponseStringHeader =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">";

static char *kMegaResponseStringAppFormat =
"    <app appid=\"%@\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test2.dmg\" hash=\"hcqiyPD01sWXVdYHNpWe4H2OBak=\" needsadmin=\"false\" size=\"1868800\" status=\"ok\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>";

static char *kMegaResponseStringFooter =
"</gupdate>";

- (void)testMultiResponse {
  // 2 apps
  NSArray *updateInfos = [self updateInfoForStr:kMultiResponseString];
  STAssertEquals([updateInfos count], 2U, nil);
  KSUpdateInfo *info = nil;
  NSEnumerator *infoEnumerator = [updateInfos objectEnumerator];
  while ((info = [infoEnumerator nextObject])) {
    if ([[info productID] isEqualToString:@"{26EA52A6-C1F2-11DB-B91C-B0B155D89593}"]) {
      // 1 - The first app listed in kMultiResponseString
      STAssertEqualObjects([info codebaseURL], [NSURL URLWithString:@"http://tools.google.com/omaha_download/test2.dmg"], nil);
      STAssertEqualObjects([info codeSize], [NSNumber numberWithInt:1868800], nil);
      STAssertEqualObjects([info codeHash], @"hcqiyPD01sWXVdYHNpWe4H2OBak=", nil);
      STAssertFalse([[info promptUser] boolValue], nil);
      STAssertFalse([[info requireReboot] boolValue], nil);
      STAssertEqualObjects([info moreInfoURLString], @"http://google.com", nil);
    } else if ([[info productID] isEqualToString:@"{8A69D345-D564-463C-AFF1-A69D9E530F96}"]) {
      // 2 - The second app listed in kMultiResponseString
      STAssertEqualObjects([info codebaseURL], [NSURL URLWithString:@"http://tools.google.com/omaha_download/test.dmg"], nil);
      STAssertEqualObjects([info codeSize], [NSNumber numberWithInt:5910016], nil);
      STAssertEqualObjects([info codeHash], @"vaQXjdS1P6VP31rkqe8YuzbNzvk=", nil);
      STAssertTrue([[info promptUser] boolValue], nil);
      STAssertTrue([[info requireReboot] boolValue], nil);
      STAssertEqualObjects([info moreInfoURLString],
                           @"http://desktop.google.com/mac/${hl}/foobage.html",
                           nil);
      STAssertEqualObjects([info localizationBundle], @"/Hassel/Hoff", nil);
      STAssertEqualObjects([info displayVersion], @"3.1.4", nil);
      STAssertEqualObjects([info version], @"3.1.4 (lolcat)", nil);
    }
  }

  // 101 apps
  unsigned int count = 101;
  NSMutableString *mega = [NSMutableString stringWithCapacity:4096];
  [mega appendString:[NSString stringWithCString:kMegaResponseStringHeader]];
  for (int x = 0; x < count; x++) {
    NSString *megaf = [NSString stringWithCString:kMegaResponseStringAppFormat];
    [mega appendString:[NSString stringWithFormat:megaf,
                                 [NSString stringWithFormat:@"{guid-%d}", x]]];
  }
  [mega appendString:[NSString stringWithCString:kMegaResponseStringFooter]];
  updateInfos = [self updateInfoForStr:[mega UTF8String]];
  STAssertEquals([updateInfos count], count, nil);
}

- (NSDictionary *)paramsDict {
  // Yes, this is active.
  NSDictionary *product0Params = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithBool:YES], kUpdateEngineProductStatsActive, nil];
  // No, this is not active.
  NSDictionary *product1Params = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithBool:NO], kUpdateEngineProductStatsActive, nil];
  // Active not explicitly set.
  NSDictionary *product2Params = [NSDictionary dictionary];

  NSDictionary *productStats = [NSDictionary dictionaryWithObjectsAndKeys:
     product0Params, @"{guid-0}",
     product1Params, @"{guid-1}",
     product2Params, @"{guid-2}",
     nil];

  NSString *machine = @"{machine-guid-goes-here}";
  NSString *user = @"{users-need-both-love-and-guids}";
  NSString *sp = @"10.982.903404";
  NSString *tag = @"aJEyA_is_our_tesTER";
  NSArray *objects = [NSArray arrayWithObjects:machine, user, sp, tag, @"1",
                              productStats, nil];
  NSArray *keys = [NSArray arrayWithObjects:kUpdateEngineMachineID,
                           kUpdateEngineUserGUID,
                           kUpdateEngineOSVersion,
                           kUpdateEngineUpdateCheckTag,
                           kUpdateEngineIsMachine,
                           kUpdateEngineProductStats,
                           nil];

  NSDictionary *params = [NSDictionary dictionaryWithObjects:objects
                                                     forKeys:keys];
  return params;
}

- (void)testParams {

  NSDictionary *params = [self paramsDict];
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_ params:params];
  NSMutableArray *oneTicket = [NSMutableArray arrayWithCapacity:1];
  [oneTicket addObject:[httpTickets_ objectAtIndex:0]];

  NSArray *requests = [server requestsForTickets:oneTicket];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  NSString *machine = [params objectForKey:kUpdateEngineMachineID];
  NSString *user = [params objectForKey:kUpdateEngineUserGUID];
  NSString *sp = [params objectForKey:kUpdateEngineOSVersion];
  NSString *tag = [params objectForKey:kUpdateEngineUpdateCheckTag];

  [self findInDoc:doc path:@".//o:gupdate/o:app" count:1];
  NSXMLNode *node;
  node = [self findInDoc:doc path:@".//o:gupdate/o:os/@version" count:1];
  STAssertTrue([[node stringValue] isEqual:@"MacOSX"], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/o:os/@platform" count:1];
  STAssertTrue([[node stringValue] isEqual:@"mac"], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/o:os/@sp" count:1];
  STAssertTrue([[node stringValue] isEqual:sp], nil);

  node = [self findInDoc:doc path:@".//o:gupdate/@version" count:1];
  STAssertTrue([[node stringValue] hasPrefix:@"UpdateEngine-"], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/@machineid" count:1];
  STAssertTrue([[node stringValue] isEqual:machine], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/@ismachine" count:1];
  STAssertTrue([[node stringValue] isEqual:@"1"], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/@userid" count:1];
  STAssertTrue([[node stringValue] isEqual:user], nil);

  node = [self findInDoc:doc path:@".//o:gupdate/@tag" count:1];
  STAssertTrue([[node stringValue] isEqual:tag], nil);

  // Make sure changing the identity affects the request.
  NSMutableDictionary *mutableParams = [[params mutableCopy] autorelease];
  [mutableParams setObject:@"Monkeys" forKey:kUpdateEngineIdentity];
  server = [KSOmahaServer serverWithURL:httpURL_ params:mutableParams];
  requests = [server requestsForTickets:oneTicket];
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  node = [self findInDoc:doc path:@".//o:gupdate/@version" count:1];
  STAssertTrue([[node stringValue] hasPrefix:@"Monkeys-"], nil);
}

- (void)testStats {
  NSURL *url = [NSURL URLWithString:@"https://www.google.com"];
  KSOmahaServer *omaha = [KSOmahaServer serverWithURL:url];
  STAssertNotNil(omaha, nil);

  NSURLRequest *request = nil;
  request = [omaha requestForStats:nil];
  STAssertNil(request, nil);

  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:@"/dev/null"
                                                        autoSynchronize:NO];
  STAssertNotNil(stats, nil);

  request = [omaha requestForStats:stats];
  STAssertNil(request, nil);

  // OK, now set some real stats, and make sure they show up correctly in the
  // XML request

  [stats incrementStat:@"foo"];
  [stats incrementStat:@"bar"];
  [stats decrementStat:@"baz"];

  [stats incrementStat:KSMakeProductStatKey(@"com.google.test1", kStatInstallRC)];
  [stats incrementStat:KSMakeProductStatKey(@"com.google.test1", kStatInstallRC)];

  [stats incrementStat:KSMakeProductStatKey(@"com.google.test2", kStatInstallRC)];
  [stats incrementStat:KSMakeProductStatKey(@"com.google.test2", kStatActiveProduct)];

  [stats incrementStat:KSMakeProductStatKey(@"com.google.test3", kStatActiveProduct)];

  request = [omaha requestForStats:stats];
  STAssertNotNil(request, nil);

  NSData *data = [request HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  NSXMLNode *node = nil;

  // Check the "kstat" element
  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat" count:1];
  STAssertNotNil(node, nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat/@foo" count:1];
  STAssertEqualObjects([node stringValue], @"1", nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat/@bar" count:1];
  STAssertEqualObjects([node stringValue], @"1", nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat/@baz" count:1];
  STAssertEqualObjects([node stringValue], @"-1", nil);


  // Check the per-app stats
  [self findInDoc:doc path:@"//o:gupdate/o:app/@appid" count:3];

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test1']/o:event" count:1];
  STAssertNotNil(node, nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test1']/o:event/@errorcode" count:1];
  STAssertNotNil(node, nil);
  STAssertEqualObjects([node stringValue], @"2", nil);

  // Here we just check to make sure that 'test1' doesn't have the ping/@active attribute at all
  [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test1']/o:ping/@active" count:0];


  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test2']/o:event" count:1];
  STAssertNotNil(node, nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test2']/o:event/@errorcode" count:1];
  STAssertNotNil(node, nil);
  STAssertEqualObjects([node stringValue], @"1", nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test2']/o:ping/@active" count:1];
  STAssertNotNil(node, nil);
  STAssertEqualObjects([node stringValue], @"1", nil);


  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test3']/o:ping/@active" count:1];
  STAssertNotNil(node, nil);
  STAssertEqualObjects([node stringValue], @"1", nil);
}

- (void)testActives {
  NSDictionary *params = [self paramsDict];

  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_ params:params];
  STAssertNotNil(server, nil);

  // Make sure the utillity function processes the params correctly.
  STAssertTrue([server isProductActive:@"{guid-0}"], nil);  // exists - true
  STAssertFalse([server isProductActive:@"{guid-1}"], nil);  // exists - false
  STAssertFalse([server isProductActive:@"{guid-2}"], nil);  // active not exist
  STAssertFalse([server isProductActive:@"{guid-3}"], nil);  // no prod stat

  // Make sure the proper active values make it out to the server request.
  int size = 4;
  NSMutableArray *tickets = [NSMutableArray arrayWithCapacity:size];
  for (int i = 0; i < size; i++) {
    [tickets addObject:[self ticketWithURL:httpURL_ count:i]];
  }
  NSArray *requests = [server requestsForTickets:tickets];
  STAssertTrue([requests count] == 1, nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSArray *actives =
    [self findInDoc:doc path:@".//o:gupdate/o:app/o:ping/@active" count:size];
  // Convert XML elements 'active="X"' to @"X".
  NSArray *values = [actives valueForKey:@"stringValue"];
  // First app should be active, the rest not.
  NSArray *expectedValues =
    [NSArray arrayWithObjects:@"1", @"0", @"0", @"0", nil];
  STAssertTrue([expectedValues isEqualToArray:values], nil);
}

- (void)testInstallAge {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  STAssertNotNil(server, nil);

  // Make a date.  The little bit of extra is to ensure we go beyond three days.
  NSTimeInterval threeDaysAgo = 3 * 24 * 60 * 60 + 37;
  NSDate *creationDate = [NSDate dateWithTimeIntervalSinceNow:-threeDaysAgo];
  STAssertNotNil(creationDate, nil);

  KSTicket *t = [self ticketWithURL:httpURL_
                              count:0
                       creationDate:creationDate];
  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSString *installage =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@installage" count:1];
  // Convert XML element 'installage="X"' to @"X".
  NSString *value = [installage valueForKey:@"stringValue"];
  STAssertEqualObjects(@"3", value, nil);

  // Check a date from the future!
  NSTimeInterval oneWeekFromNow = 7 * 24 * 60 * 60 + 42;

  creationDate = [NSDate dateWithTimeIntervalSinceNow:oneWeekFromNow];
  STAssertNotNil(creationDate, nil);

  t = [self ticketWithURL:httpURL_
                    count:0
             creationDate:creationDate];
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  installage =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@installage" count:0];
  // Should be nothing there.
  STAssertEqualObjects(installage, [NSArray array], nil);
}

- (void)testTag {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  STAssertNotNil(server, nil);

  KSTicket *t = [self ticketWithURL:httpURL_
                              count:0
                                tag:@"oonga woonga"];
  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSString *tagNode =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@tag" count:1];

  // Convert XML element 'tag="X"' to @"X".
  NSString *value = [tagNode valueForKey:@"stringValue"];
  STAssertEqualObjects(@"oonga woonga", value, nil);

  // No tag should result in no "tag".
  t = [self ticketWithURL:httpURL_ count:0];
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  tagNode = [self findInDoc:doc path:@".//o:gupdate/o:app/@tag" count:0];
}

- (void)testBrand {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  STAssertNotNil(server, nil);

  KSTicket *t =
    [self ticketWithURL:httpURL_
                  count:0
              brandPath:@"/Applications/TextEdit.app/Contents/Info.plist"
               brandKey:@"CFBundleDisplayName"];

  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSString *brandNode =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@brand" count:1];

  // Convert XML element 'brand="X"' to @"X".
  NSString *value = [brandNode valueForKey:@"stringValue"];
  STAssertEqualObjects(@"TextEdit", value, nil);

  // No brand should result in the default "GGLG" brand.
  t = [self ticketWithURL:httpURL_ count:0];
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  brandNode = [self findInDoc:doc path:@".//o:gupdate/o:app/@brand" count:1];
  value = [brandNode valueForKey:@"stringValue"];
  STAssertEqualObjects(DEFAULT_BRAND_CODE, value, nil);
}

- (void)testIsAllowedURL {
  NSURL *url = [NSURL URLWithString:@"https://placeholder.com"];
  KSOmahaServer *server = [KSOmahaServer serverWithURL:url params:nil];

  STAssertFalse([server isAllowedURL:nil], nil);

#ifdef DEBUG
  // In DEBUG mode, everything is allowed.  Go nuts.
  url = [NSURL URLWithString:@"file:///bin/ls"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"http://google.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://google.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"fish://glub/glub"];
  STAssertTrue([server isAllowedURL:url], nil);
#else
  // In release mode, all non-https urls are summarily rejected.
  url = [NSURL URLWithString:@"file:///bin/ls"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"http://google.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"pheasant://grouse/grouse"];
  STAssertFalse([server isAllowedURL:url], nil);

  // If no allowed subdomains are supplied, allow any https urls.
  url = [NSURL URLWithString:@"https://snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);

  // Supply a set of allowed subdomains, and make sure those are, well,
  // allowed.
  NSArray *allowedSubdomains = [NSArray arrayWithObjects:
                                        @".update.snorklegronk.com",
                                        @".www.snorklegronk.com",
                                        @".intranet.grouse.grouse", nil];
  NSDictionary *params =
    [NSDictionary dictionaryWithObjectsAndKeys:allowedSubdomains,
                  kUpdateEngineAllowedSubdomains, nil];
  url = [NSURL URLWithString:@"https://pheasant.intranet.grouse.grouse"];
  server = [KSOmahaServer serverWithURL:url params:params];

  // Make sure allowed domains are allowed.
  url = [NSURL URLWithString:@"https://update.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://splunge.update.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://intranet.grouse.grouse"];
  STAssertTrue([server isAllowedURL:url], nil);

  // And double-check other domains
  url = [NSURL URLWithString:@"https://backup.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  // Don't allow cloaking.
  url = [NSURL URLWithString:@"https://www.snorklegronk.com.badguy.com"];
  STAssertFalse([server isAllowedURL:url], nil);

  // And sanity check that non-https are still rejected.
  url = [NSURL URLWithString:@"file:///update.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"http://www.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"pheasant://grouse.grouse.grouse"];
  STAssertFalse([server isAllowedURL:url], nil);

  // Make sure overlapping domains don't cause unexpected behavior
  allowedSubdomains = [NSArray arrayWithObjects:
                               @".www.snorklegronk.com",
                               @".www.snorklegronk.com", nil];
  params = [NSDictionary dictionaryWithObjectsAndKeys:allowedSubdomains,
                         kUpdateEngineAllowedSubdomains, nil];
  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  server = [KSOmahaServer serverWithURL:url params:params];

  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://monkeys.www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://backup.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
#endif
}

@end

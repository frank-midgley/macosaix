#import "GoogleImageSource.h"

@implementation GoogleImageSource

- (id)initWithObject:(id)theObject
{
    [super init];

    if ([theObject isKindOfClass:[NSString class]])
    {
	_query = [theObject copy];
	_imageURLQueue = [[NSMutableArray arrayWithCapacity:0] retain];

	// prime the pump
//	_nextGooglePage = [[NSURL URLWithString:@"http://images.google.com/images?q=bear&name=ie&name=oe&hl=en"]
//			   retain];
	_nextGooglePage = [[NSURL URLWithString:[@"http://images.google.com/images?name=ie&name=oe&hl=en&q=" stringByAppendingString:_query]] retain];
    }
    else
    {
	[self autorelease];
	return nil;
    }
    return self;
}


- (NSImage *)typeImage;
{
    return [NSImage imageNamed:@"GoogleImageSource"];
}


- (NSString *)descriptor
{
    return [_query stringByAppendingString:@" images"];
}


- (NSURL *)nextImageURL
{
    NSURL	*imageURL, *possibleNextGooglePage = nil;
    
    // if queue is empty, get next page from Google and parse out the image URL's
    // and the link to the next page
    if ([_imageURLQueue count] == 0 && _nextGooglePage)
    {
	NSString		*URLcontent;
	NSArray			*tags;
	int			index;
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	// get the HTML of the results page
	URLcontent = [NSString stringWithContentsOfURL:_nextGooglePage];
	while (!URLcontent)
	{
	    NSLog(@"Could not load URL %@", _nextGooglePage);
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	    URLcontent = [NSString stringWithContentsOfURL:_nextGooglePage];
	}
	
	[_nextGooglePage autorelease];
	_nextGooglePage = nil;

	// break up the HTML by tags and extrct images and links
	tags = [URLcontent componentsSeparatedByString:@"<"];
	for (index = 0; index < [tags count]; index++)
	{
	    NSString	*tag = [tags objectAtIndex:index];
	    NSRange	src;
	    
	    if ([tag hasPrefix:@"img "])
	    {
		src = [tag rangeOfString:@" src="];
		src.location += 5;
		src.length = [tag length] - src.location;
		tag = [tag substringWithRange:src];
		src = [tag rangeOfString:@" "];
		src.length = src.location;
		src.location = 0;
		if ([[tag substringWithRange:src] hasPrefix:@"/images?"])
		    [_imageURLQueue addObject:[[NSURL URLWithString:[@"http://images.google.com"
						    stringByAppendingString:[tag substringWithRange:src]]
						 ] retain]];
		if ([tag hasPrefix:@"/nav_next"])
		{
		    _nextGooglePage = [possibleNextGooglePage retain];
		}
	    }
	    else
		if ([tag hasPrefix:@"a href=/images?"])
		{
		    // this will actually get hit for each page of results,
		    // but the link to the next page is the last one
		    src.location = 7;
		    src.length = [tag length] - 8;
		    possibleNextGooglePage = [NSURL URLWithString:[@"http://images.google.com"
						    stringByAppendingString:[tag substringWithRange:src]]];
		}
	}
	[pool release];
    }
    
    if ([_imageURLQueue count] > 0)
    {
	imageURL = [_imageURLQueue objectAtIndex:0];
	[_imageURLQueue removeObjectAtIndex:0];
	_imageCount++;
	return imageURL;
    }
    else
	return nil;	// no more images
}

@end

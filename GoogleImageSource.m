#import "GoogleImageSource.h"
#import <CoreFoundation/CFURL.h>

@implementation GoogleImageSource

- (id)initWithObject:(id)theObject
{
    [super initWithObject:theObject];

    if ([theObject isKindOfClass:[NSString class]])
    {
	NSString *encodedQuery;
	
	_query = [theObject copy];
	encodedQuery = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)_query, 
									    NULL, NULL, kCFStringEncodingUTF8);
	_imageURLQueue = [[NSMutableArray arrayWithCapacity:0] retain];

	_nextGooglePage = [[NSURL URLWithString:[@"http://images.google.com/images?name=ie&name=oe&hl=en&q=" 
						 stringByAppendingString:encodedQuery]] retain];
    }
    else
    {
	[self autorelease];
	return nil;
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    _query = [[coder decodeObject] retain];
    _nextGooglePage= [[coder decodeObject] retain];
    _imageURLQueue = [[coder decodeObject] retain];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_query];
    [coder encodeObject:_nextGooglePage];
    [coder encodeObject:_imageURLQueue];
}


- (NSImage *)typeImage;
{
    return [NSImage imageNamed:@"GoogleImageSource"];
}


- (NSString *)descriptor
{
    return [_query stringByAppendingString:@" images"];
}


- (id)nextImageIdentifier
{
    NSURL	*possibleNextGooglePage = nil;
    
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
		if ([[tag substringWithRange:src] hasPrefix:@"/images?q="])
		{
		    src.location = 10;	// only use what comes after "/images?q=" to save memory 
		    src.length -= 10;
		    [_imageURLQueue addObject:[tag substringWithRange:src]];
		}
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
	NSString	*imageURLString = [[_imageURLQueue objectAtIndex:0] retain];
	
	[_imageURLQueue removeObjectAtIndex:0];
	_imageCount++;
	return imageURLString;
    }
    else
	return nil;	// no more images
}


- (NSImage *)imageForIdentifier:(id)identifier
{
    return [super imageForIdentifier:
	[NSURL URLWithString:[NSString stringWithFormat:@"http://images.google.com/images?q=%@", identifier]]];
}

@end

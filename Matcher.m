//
//  Matcher.m
//  MacOSaiX
//
//  Created by fmidgley on Tue Mar 20 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import "Matcher.h"

@implementation Matcher

+ (void)connectWithPorts:(NSArray *)portArray
{
    NSAutoreleasePool *pool;
    NSConnection *serverConnection;
    Matcher *serverObject;

    pool = [[NSAutoreleasePool alloc] init];

    serverConnection = [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0]
	sendPort:[portArray objectAtIndex:1]];

    // create an instance of this class and send a reference back to the client thread
    serverObject = [[self alloc] initWithProxy:(id)[serverConnection rootProxy]];
    [(id)[serverConnection rootProxy] setServer:serverObject];
    [serverObject release];	// the client thread retains the instance

    [[NSRunLoop currentRunLoop] run];
    [pool release];
    pool = nil;
    [NSThread exit];

    return;
}


- (id)initWithProxy:(id)proxyObject
{
    //[self init];	// perform inherited init methods?
    _tiles = nil;
    [proxyObject setProtocolForProxy:@protocol(ControllerMethods)];
    clientProxy = (id <ControllerMethods>)[proxyObject retain];
    return self;
}

- (void)setTileCollection:(TileCollection *)tiles
{
    NSLog(@"Setting tile collection");
    if (_tiles != nil) [_tiles autorelease];
    _tiles = [tiles retain];
    NSLog(@"Exiting setTileCollection");
}

//- (oneway void)calculateMatches:(in NSMutableArray*)tileImages withFile:(NSString*)filePath
//- (oneway void)calculateMatches:(bycopy NSBitmapImageRep *[])tileImages count:(int)tileCount withFile:(NSString*)filePath
- (oneway void)calculateMatchesWithFile:(NSString*)filePath connection:(id)connection
{
    int				imageCount, index = 0;
    NSImage			*pixletImage;
    NSRect			subRect;
    NSBitmapImageRep		*tileImageRep, *pixletRep;
    float			matchValue;
    //NSMutableArray		*tileImages;
    Tile			*tile;
    
    NSLog(@"Entering calculateMatchesWithFile...");
    NSAssert(_tiles != nil, @"_tiles is nil");
    //tileImages = (NSMutableArray *)[clientProxy getTileImages];
    NSLog(@"Getting count of tiles");
    imageCount = [_tiles count];
    
//    match = (float *)malloc(sizeof(float) * imageCount);
    
    // load the pixlet image
    pixletImage = [[NSImage alloc] initWithContentsOfFile:filePath];
    if ([pixletImage isValid])
    {
	//create an NSBitmapImageRep from the image for direct pixel access
	[pixletImage setScalesWhenResized:YES];
	
	// loop through the tiles of the main image and compute the pixlet's match
	for (index = 0; index < imageCount; index++)
	{
	    NSLog(@"About to compare tile %s to pixlet %d of main image.\n", filePath, index);
	    //tileImageRep = [(NSMutableArray *)_tiles objectAtIndex:index];
	    //[clientProxy getTileImageRep:index];
	    //NSAssert(tileImageRep, @"tileImageRep is nil");
	    tile = [_tiles tileAtIndex:index];
	    NSAssert(tile != nil, @"tiles is nil");
	    [pixletImage setSize:[tile size]];
	    subRect.origin.x = subRect.origin.y = 0.0;
	    subRect.size = [pixletImage size];
	    [pixletImage lockFocus];
	    pixletRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [pixletImage size].width, [pixletImage size].height)];
	    [pixletImage unlockFocus];
	    NSAssert(pixletRep, @"pixletRep not allocated");
	    matchValue = [self computeMatch:tile with:pixletRep];
	    [clientProxy checkInMatch:matchValue atIndex:index forFile:filePath];
	    [pixletRep release];
	    pixletRep = nil;
	    NSLog(@"Finished comparing tile %s to pixlet %d of main image.\n", filePath, index);
	}
    }
    [pixletImage release];
    pixletImage = nil;
    //[filePath release];
    
    // check in the matches
    //[clientProxy checkInMatch:match forFile:filePath];
}

- (float)computeMatch:(Tile *)tile with:(NSBitmapImageRep *)imageRep
{
    int			width, height, x, y, redDiff, greenDiff, blueDiff;
    unsigned char	*bitmap1, *bitmap2;
    float		matchValue = 0.0;
    
    if (tile == nil || imageRep == nil) return 0.0;
    
    bitmap1 = (unsigned char *)[[tile bitmapData] bytes];
    NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    bitmap2 = [imageRep bitmapData];
    NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    width = [tile size].width;
    height = [tile size].height;
    for (x = 0; x < width; x++)
	for (y = 0; y < height; y++)
	{
	    redDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    greenDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    blueDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    bitmap1++; bitmap2++;	//skip alpha value
	    
	    matchValue += redDiff * greenDiff * blueDiff;

/*	    if ((redDiff < 16 && (greenDiff < 32 || blueDiff < 32)) ||
	    	(greenDiff < 16 && (redDiff < 32 || blueDiff < 32)) ||
	    	(blueDiff < 16 && (redDiff < 32 || greenDiff < 32))) matchValue += 1.0;
	    if (redDiff < 16 && greenDiff < 16 && blueDiff < 16) matchValue += 4.0;	*/
	}
    NSLog(@"Match value=%f\n", matchValue);
    return matchValue;
}

-(void)dealloc
{
    if (_tiles != nil) [_tiles dealloc];
    [super dealloc];
}

@end

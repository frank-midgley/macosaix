#import "TileImage.h"


@interface TileImage (PrivateMethods)
- (void)removeImageFromCache;
@end


@implementation TileImage

static int				sMaxLoadedImages = 512;
static NSMutableArray	*sLoadedTileImages = nil;
static NSRecursiveLock	*sLoadImageLock = nil,
						*sRemoveImageFromCacheLock = nil;

+ (void)initialize
{
    sLoadedTileImages = [[NSMutableArray arrayWithCapacity:sMaxLoadedImages] retain];
    sLoadImageLock = [[NSRecursiveLock alloc] init];
    sRemoveImageFromCacheLock = sLoadImageLock;	//[[NSRecursiveLock alloc] init];
}


- (id)initWithIdentifier:(id)identifier fromImageSource:(ImageSource *)imageSource
{
    if (identifier == nil) NSLog(@"Illegal TileImage initialization");
    self = [super init];
    imageIdentifier = [identifier retain];
    imageSource = [imageSource retain];
    useCount = 0;
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
//    imageSource = [[coder decodeObject] retain];
    imageSource = [[coder decodeObject] retain];
    useCount = [[coder decodeObject] intValue];
    imageIdentifier = [[coder decodeObject] retain];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
//    [coder encodeObject:imageSource];
    [coder encodeObject:imageSource];
    [coder encodeObject:[NSNumber numberWithInt:useCount]];
    [coder encodeObject:imageIdentifier];
}


- (ImageSource *)imageSource
{
    return imageSource;
}


- (id)imageIdentifier
{
    return imageIdentifier;
}


- (NSImage *)image;
{
    NSImage	*imageRef = nil;
    
    [sRemoveImageFromCacheLock lock];
		imageRef = [[image retain] autorelease];
    [sRemoveImageFromCacheLock unlock];
    
    if (imageRef != nil)
    {
			// Our image is cached.
			// move ourself to the head of the cache so we don't get de-allocated so soon
		[sRemoveImageFromCacheLock lock];
			[sLoadedTileImages removeObjectIdenticalTo:[self retain]];
			[sLoadedTileImages insertObject:self atIndex:0];
			[self release];
		[sRemoveImageFromCacheLock unlock];
		return imageRef;
    }

		// we weren't cached, reload our image from the image source
    imageRef = [imageSource imageForIdentifier:imageIdentifier];

    if (imageRef != nil)
    {
		if (!thumbnail)
		{
				// Make a permanent 
			thumbnail = [imageRef copy];
			[thumbnail setScalesWhenResized:YES];
			
				// Scale the image down to 128 pixels on its smaller axis to save memory
			if ([thumbnail size].width < [thumbnail size].height && [thumbnail size].width > 128)
				[thumbnail setSize:NSMakeSize(128, 128 * [thumbnail size].height / [thumbnail size].width)];
			if ([thumbnail size].width > [thumbnail size].height && [thumbnail size].height > 128)
				[thumbnail setSize:NSMakeSize(128 * [thumbnail size].width / [thumbnail size].height, 128)];
		}
		
			// Scale the image down to 128 pixels on its smaller axis to save memory
		if ([imageRef size].width < [imageRef size].height && [imageRef size].width > 128)
		{
			[imageRef setSize:NSMakeSize(128, 128 * [imageRef size].height / [imageRef size].width)];
			[imageRef recache];
		}
		if ([imageRef size].width > [imageRef size].height && [imageRef size].height > 128)
		{
			[imageRef setSize:NSMakeSize(128 * [imageRef size].width / [imageRef size].height, 128)];
			[imageRef recache];
		}
		
		[sLoadImageLock lock];
			if (image == nil)	// otherwise another thread loaded it
			{
				image = [imageRef retain];
				
					// add ourself to the list of images that are loaded
				[sLoadedTileImages insertObject:self atIndex:0];
				[self release];
				
					// unload another image if the cache is full
				//[unloadImageLock lock];
					if ([sLoadedTileImages count] > sMaxLoadedImages)
					[(TileImage *)[sLoadedTileImages lastObject] removeImageFromCache];
				//[unloadImageLock unlock];
			}
		[sLoadImageLock unlock];
    }
    
    return imageRef;
}


- (NSImage *)thumbnail
{
	return [[thumbnail retain] autorelease];
}


- (void)removeImageFromCache
{
    [sRemoveImageFromCacheLock lock];
		//NSLog(@"\n\tUnloading %@", imageIdentifier);
		[image release];
		image = nil;
		[self retain];
		[sLoadedTileImages removeObjectIdenticalTo:self];
    [sRemoveImageFromCacheLock unlock];
}


- (void)imageIsInUse
{
	[self retain];
    useCount++;
}


- (BOOL)imageIsNotInUse
{
	[self autorelease];
    return (--useCount == 0);
}


- (void)dealloc
{
    [sRemoveImageFromCacheLock lock];
	//NSLog(@"\n\tDeallocating %@", imageIdentifier);
	if (image != nil) [self removeImageFromCache];
	[imageIdentifier release];
    [sRemoveImageFromCacheLock unlock];

	[super dealloc];
}

@end

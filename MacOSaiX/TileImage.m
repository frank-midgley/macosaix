#import "TileImage.h"

@implementation TileImage

static int		_maxLoadedImages;
static NSMutableArray	*_loadedTileImages;
static NSRecursiveLock	*_loadImageLock, *_removeImageFromCacheLock;

+ (void)initialize
{
    _maxLoadedImages = 512;
    _loadedTileImages = [[NSMutableArray arrayWithCapacity:_maxLoadedImages] retain];
    _loadImageLock = [[NSRecursiveLock alloc] init];
    _removeImageFromCacheLock = _loadImageLock;	//[[NSRecursiveLock alloc] init];
}


- (id)initWithIdentifier:(id)identifier fromImageSource:(ImageSource *)imageSource
{
    if (identifier == nil) NSLog(@"Illegal TileImage initialization");
    self = [super init];
    _imageIdentifier = [identifier retain];
    _imageSource = [imageSource retain];
    _useCount = 0;
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
//    _imageSource = [[coder decodeObject] retain];
    _imageSource = [[coder decodeObject] retain];
    _useCount = [[coder decodeObject] intValue];
    _imageIdentifier = [[coder decodeObject] retain];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
//    [coder encodeObject:_imageSource];
    [coder encodeObject:_imageSource];
    [coder encodeObject:[NSNumber numberWithInt:_useCount]];
    [coder encodeObject:_imageIdentifier];
}


- (ImageSource *)imageSource
{
    return _imageSource;
}


- (id)imageIdentifier
{
    return _imageIdentifier;
}


- (NSImage *)image;
{
    NSImage	*imageRef;
    
    [_removeImageFromCacheLock lock];
		imageRef = [_image retain];
		[imageRef autorelease];
    [_removeImageFromCacheLock unlock];
    
    if (imageRef != nil)
    {
			// Our image is cached.
			// move ourself to the head of the cache so we don't get de-allocated so soon
		[_removeImageFromCacheLock lock];
			[_loadedTileImages removeObjectIdenticalTo:[self retain]];
			[_loadedTileImages insertObject:self atIndex:0];
			[self release];
		[_removeImageFromCacheLock unlock];
		return imageRef;
    }

		// we weren't cached, reload our image from the image source
    imageRef = [_imageSource imageForIdentifier:_imageIdentifier];

    if (imageRef != nil)
    {
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
		
		[_loadImageLock lock];
			if (_image == nil)	// otherwise another thread loaded it
			{
				_image = [imageRef retain];
				
					// add ourself to the list of images that are loaded
				[_loadedTileImages insertObject:self atIndex:0];
				[self release];
				
					// unload another image if the cache is full
				//[_unloadImageLock lock];
					if ([_loadedTileImages count] > _maxLoadedImages)
					[(TileImage *)[_loadedTileImages lastObject] removeImageFromCache];
				//[_unloadImageLock unlock];
			}
		[_loadImageLock unlock];
    }
    
    return imageRef;
}


- (void)removeImageFromCache
{
    [_removeImageFromCacheLock lock];
		//NSLog(@"\n\tUnloading %@", _imageIdentifier);
		[_image release];
		_image = nil;
		[self retain];
		[_loadedTileImages removeObjectIdenticalTo:self];
    [_removeImageFromCacheLock unlock];
}


- (void)imageIsInUse
{
	[self retain];
    _useCount++;
}


- (BOOL)imageIsNotInUse
{
	[self autorelease];
    return (--_useCount == 0);
}


- (void)dealloc
{
    [_removeImageFromCacheLock lock];
	//NSLog(@"\n\tDeallocating %@", _imageIdentifier);
	if (_image != nil) [self removeImageFromCache];
	[_imageIdentifier release];
	[super dealloc];
    [_removeImageFromCacheLock unlock];
}

@end

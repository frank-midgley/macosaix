#import "TileImage.h"

@implementation TileImage

static int		_maxLoadedImages;
static NSMutableArray	*_loadedTileImages;
static NSRecursiveLock	*_loadImageLock, *_unloadImageLock;

+ (void)initialize
{
    _maxLoadedImages = 512;
    _loadedTileImages = [[NSMutableArray arrayWithCapacity:_maxLoadedImages] retain];
    _loadImageLock = [[NSRecursiveLock alloc] init];
    _unloadImageLock = _loadImageLock;	//[[NSRecursiveLock alloc] init];
}


- (id)initWithIdentifier:(id)identifier fromSource:(ImageSource *)imageSource
{
    if (identifier == nil || imageSource == nil)
	NSLog(@"Illegal TileImage initialization");
    self = [super init];
    _imageIdentifier = [identifier retain];
    _imageSource = [imageSource retain];
    return self;
}


- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    _imageSource = [[coder decodeObject] retain];
    _imageIdentifier = [[coder decodeObject] retain];
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_imageSource];
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


- (NSImage *)image
{
    NSImage	*imageRef;
    
    [_unloadImageLock lock];
	imageRef = [_image retain];
	[imageRef autorelease];
    [_unloadImageLock unlock];
    
    if (imageRef != nil)
    {
	// move ourself to the head of the cache so we don't get de-allocated so soon
	[_unloadImageLock lock];
	    [_loadedTileImages removeObjectIdenticalTo:[self retain]];
	    [_loadedTileImages insertObject:self atIndex:0];
	    [self release];
	[_unloadImageLock unlock];
	return imageRef;
    }

    //NSLog(@"\n\tLoading %@", _imageIdentifier);
    // load the image
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
		
		// unload another image if the cache is full
		//[_unloadImageLock lock];
		    if ([_loadedTileImages count] > _maxLoadedImages)
			[(TileImage *)[_loadedTileImages lastObject] unloadImage];
		//[_unloadImageLock unlock];
	    }
	[_loadImageLock unlock];
    }
    
    return _image;
}


- (void)unloadImage
{
    [_unloadImageLock lock];
	//NSLog(@"\n\tUnloading %@", _imageIdentifier);
	[_image release];
	_image = nil;
	[_loadedTileImages removeObjectIdenticalTo:self];
    [_unloadImageLock unlock];
}


- (void)dealloc
{
    [_unloadImageLock lock];
	//NSLog(@"\n\tDeallocating %@", _imageIdentifier);
	if (_image != nil) [self unloadImage];
	[_imageIdentifier release];
	[_imageSource release];
	[super dealloc];
    [_unloadImageLock unlock];
}

@end

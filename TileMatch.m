#import "TileMatch.h"

@implementation TileMatch

- (id)init
{
    [super init];
    _imageURL = nil;
    _matchValue = WORST_CASE_PIXEL_MATCH;
    return self;
}

- (void)setImageURL:(NSURL *)imageURL
{
    NSAssert(imageURL != nil, @"imageURL has been released");
    [_imageURL autorelease];
    _imageURL = [imageURL copy];
}


- (NSURL *)imageURL
{
    return _imageURL;
}


- (void)setBitmapRep:(NSBitmapImageRep *)bitmapRep
{
    NSBitmapImageRep	*oldBitmapRep;
    
    if (bitmapRep != _bitmapRep)
    {
	oldBitmapRep = _bitmapRep;
	_bitmapRep = [bitmapRep retain];
	[oldBitmapRep release];
	oldBitmapRep = nil;
    }
}


- (NSBitmapImageRep *)bitmapRep
{
    return _bitmapRep;
}


- (void)setMatchValue:(double)matchValue
{
    _matchValue = matchValue;
}


- (double)matchValue
{
    return _matchValue;
}


- (void)dealloc
{
    if (_imageURL != nil) [_imageURL release];
    if (_bitmapRep != nil) [_bitmapRep release];
    [super dealloc];
}


@end

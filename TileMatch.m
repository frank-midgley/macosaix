#import "TileMatch.h"

@implementation TileMatch

- (id)init
{
    [super init];
    _filePath = nil;
    return self;
}

- (void)setFilePath:(NSString *)filePath
{
    NSString	*oldFilePath;
    
    if (filePath != _filePath)
    {
	oldFilePath = _filePath;
	_filePath = [filePath retain];
	[oldFilePath release];
	oldFilePath = nil;
    }
}


- (NSString *)filePath
{
    return _filePath;
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
    if (_filePath != nil) [_filePath release];
    if (_bitmapRep != nil) [_bitmapRep release];
    [super dealloc];
}


@end

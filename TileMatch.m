#import "TileMatch.h"


@implementation TileMatch
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

- (void)setMatchValue:(double)matchValue
{
    _matchValue = matchValue;
}

- (double)matchValue
{
    return _matchValue;
}

@end

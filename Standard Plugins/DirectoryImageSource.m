#import <AppKit/AppKit.h>
#import "DirectoryImageSource.h"

@implementation DirectoryImageSource

- (id)initWithPath:(NSString *)path
{
	self = [super init];
	if (self)
	{
		_nextFile = nil;
		_directoryPath = nil;
		_enumerator = nil;
		_directoryPath = [path copy];
		_enumerator = [[[NSFileManager defaultManager] enumeratorAtPath:_directoryPath] retain];
		_haveMoreImages = YES;
	}
    return self;
}


- (NSImage *)image;
{
    return [[NSWorkspace sharedWorkspace] iconForFile:_directoryPath];
}


- (NSString *)descriptor
{
    return _directoryPath;
}


- (BOOL)hasMoreImages
{
	return _haveMoreImages;
}


- (id)nextImageIdentifier
{
    NSString	*nextFile = nil,
				*fullPath = nil;
    
    // lookup the path of the next image
    do
    {
		if (_enumerator == nil)
			nextFile = nil;
		else
		{
			if (nextFile = [_enumerator nextObject])
				fullPath = [_directoryPath stringByAppendingString:nextFile];
		}
    }
    while (nextFile != nil &&
	    (![[NSImage imageFileTypes] containsObject:[nextFile pathExtension]] ||
	     ([fullPath rangeOfString:@"iPhoto Library"].location != NSNotFound &&
	      [fullPath rangeOfString:@"Thumbs"].location != NSNotFound) ||
	     ([fullPath rangeOfString:@"iPhoto Library"].location != NSNotFound &&
	      [fullPath rangeOfString:@"Originals"].location != NSNotFound)));
    
    [_nextFile autorelease];
    
    if (nextFile != nil)
    {
		_nextFile = [nextFile retain];	// remember at which file we were for archiving
		_imageCount++;
		return nextFile;
    }
    else
	{
		_haveMoreImages = NO;
		return nil;	// no more images
	}
}


- (NSImage *)imageForIdentifier:(id)identifier
{
    return [super imageForIdentifier:
			[NSURL fileURLWithPath:[_directoryPath stringByAppendingPathComponent:identifier]]];
}

@end

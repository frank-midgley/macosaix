#import <AppKit/AppKit.h>
#import "DirectoryImageSource.h"

@implementation DirectoryImageSource

- (id)initWithObject:(id)theObject
{
    [super init];

    if ([theObject isKindOfClass:[NSString class]])
    {
	_directoryPath = [theObject copy];
	_enumerator = [[[NSFileManager defaultManager] enumeratorAtPath:_directoryPath] retain];
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
    return [[NSWorkspace sharedWorkspace] iconForFile:_directoryPath];
}


- (NSString *)descriptor
{
    return _directoryPath;
}


- (NSURL *)nextImageURL
{
    NSString	*nextFile, *fullPath;
    
    // hack to start after a certain file
    //while (nextFile = [enumerator nextObject]))
	//if (nextFile != nil && [nextFile isEqualToString:@"..."]) break;

    // lookup the path of the next image
    do
    {
	if (_enumerator == nil)
	    nextFile = nil;
	else
	{
	    nextFile = [_enumerator nextObject];
	    fullPath = [_directoryPath stringByAppendingString:nextFile];
	}
    }
    while (nextFile != nil &&
	    (![[NSImage imageFileTypes] containsObject:[nextFile pathExtension]] ||
	     ([fullPath rangeOfString:@"iPhoto Library"].location != NSNotFound &&
	      [fullPath rangeOfString:@"Thumbs"].location != NSNotFound) ||
	     ([fullPath rangeOfString:@"iPhoto Library"].location != NSNotFound &&
	      [fullPath rangeOfString:@"Originals"].location != NSNotFound)));
    
    if (nextFile != nil)
    {
	_imageCount++;
	return [[NSURL fileURLWithPath:[_directoryPath stringByAppendingPathComponent:nextFile]] retain];
    }
    else
	return nil;	// no more images
}

@end

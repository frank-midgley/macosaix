#import <AppKit/AppKit.h>
#import "DirectoryImageSource.h"

@implementation DirectoryImageSource

- (id)initWithObject:(id)theObject
{
    [super initWithObject:theObject];

    _nextFile = nil;
    _directoryPath = nil;
    _enumerator = nil;
    
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


- (id)initWithCoder:(NSCoder *)coder
{
    NSString	*nextFile;
    
    self = [super initWithCoder:coder];
    _directoryPath = [[coder decodeObject] retain];
    _nextFile = [[coder decodeObject] retain];
    
    _enumerator = [[[NSFileManager defaultManager] enumeratorAtPath:_directoryPath] retain];
    if (_nextFile != nil)
		do
			nextFile = [_enumerator nextObject];
		while (![_nextFile isEqualToString:nextFile] && nextFile != nil);
    
    return self;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_directoryPath];
    [coder encodeObject:_nextFile];
}


- (NSImage *)typeImage;
{
    return [[NSWorkspace sharedWorkspace] iconForFile:_directoryPath];
}


- (NSString *)descriptor
{
    return _directoryPath;
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
    _nextFile = [nextFile retain];	// remember at which file we were for archiving
    
    if (nextFile != nil)
    {
		_imageCount++;
		return nextFile;
    }
    else
		return nil;	// no more images
}


- (NSImage *)imageForIdentifier:(id)identifier
{
    return [super imageForIdentifier:
			[NSURL fileURLWithPath:[_directoryPath stringByAppendingPathComponent:identifier]]];
}

@end

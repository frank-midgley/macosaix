//
//  NSImage+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 11/13/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "NSImage+MacOSaiX.h"


@implementation NSImage (MacOSaiX)


- (NSImage *)copyWithLargestDimension:(float)largestDimension
{
	NSSize	copySize, originalSize = [self size];
	
	if (originalSize.width > originalSize.height)
		copySize = NSMakeSize(largestDimension, originalSize.height * largestDimension / originalSize.width);
	else
		copySize = NSMakeSize(originalSize.width * largestDimension / originalSize.height, largestDimension);
		
	NSImage	*copy = [[NSImage alloc] initWithSize:copySize];
	[copy setCacheMode:NSImageCacheNever];
	BOOL	haveFocus = NO;
	
	while (!haveFocus)	// && ???
	{
		NS_DURING
			[copy lockFocus];
			haveFocus = YES;
		NS_HANDLER
			NSLog(@"Couldn't lock focus on image copy: %@", localException);
		NS_ENDHANDLER
	}
	
	if (haveFocus)
	{
		[self drawInRect:NSMakeRect(0.0, 0.0, copySize.width, copySize.height) 
			    fromRect:NSMakeRect(0.0, 0.0, originalSize.width, originalSize.height) 
			   operation:NSCompositeCopy 
			    fraction:1.0];
		[copy unlockFocus];
	}
	else
		NSLog(@"Couldn't create cached thumbnail image.");
	
	return copy;
}


@end

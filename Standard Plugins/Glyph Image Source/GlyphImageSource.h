//
//  GlyphImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Apr 04 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MacOSaiXImageSource.h"

@interface MacOSaiXGlyphImageSource : NSObject <MacOSaiXImageSource>
{
    NSMutableArray	*fontNames,
					*colorNames;
    NSWindow		*focusWindow;	// for offscreen drawing
    NSLock			*focusWindowLock;
	
	unsigned long	imageCountLimit,
					imageCount;
}

- (void)addFontWithName:(NSString *)fontName;
- (void)removeFontWithName:(NSString *)fontName;
- (NSArray *)fontNames;

- (void)setImageCountLimit:(unsigned long)limit;
- (unsigned long)imageCountLimit;

@end

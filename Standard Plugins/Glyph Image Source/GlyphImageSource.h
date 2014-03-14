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
    NSMutableArray		*fontNames;
	NSMutableDictionary	*colorLists;
	BOOL				allowTransparentImages;
	NSString			*letterPool;
	
	unsigned long		imageCountLimit,
						imageCount;
	
	NSMutableDictionary	*glyphsDict;
	NSRect				glyphsBounds;
	
    NSWindow			*focusWindow;	// for offscreen drawing
    NSLock				*focusWindowLock;
}

+ (NSArray *)builtInColorListNames;

- (void)addFontWithName:(NSString *)fontName;
- (void)removeFontWithName:(NSString *)fontName;
- (NSArray *)fontNames;

- (void)addColorList:(NSString *)listName ofClass:(NSString *)listClass;
- (void)removeColorList:(NSString *)listName ofClass:(NSString *)listClass;
- (NSArray *)colorListsOfClass:(NSString *)listClass;

- (void)setAllowTransparentImages:(BOOL)flag;
- (BOOL)allowTransparentImages;

- (void)setLetterPool:(NSString *)pool;
- (NSString *)letterPool;

- (NSSize)glyphsSize;

- (void)setImageCountLimit:(unsigned long)limit;
- (unsigned long)imageCountLimit;

@end

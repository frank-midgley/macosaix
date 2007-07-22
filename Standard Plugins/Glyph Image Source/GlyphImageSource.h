//
//  GlyphImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Apr 04 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley. All rights reserved.
//


typedef enum MacOSaiXGlyphFontsType
{
	allFonts, 
	fontCollection, 
	fontFamily
} MacOSaiXGlyphFontsType;


@interface MacOSaiXGlyphImageSource : NSObject <MacOSaiXImageSource>
{
	MacOSaiXGlyphFontsType	fontsType;
	NSString				*fontFamilyName, 
							*fontCollectionName, 
							*colorListName, 
							*colorListClass, 
							*letterPool;
	NSNumber				*aspectRatio;
	
	BOOL					imagesShouldBeRemovedForLastChange;
	
	NSMutableDictionary		*glyphsDict;
	
    NSWindow				*focusWindow;	// for offscreen drawing
    NSLock					*focusWindowLock;
}

+ (NSArray *)builtInColorListNames;

- (void)setUseAllFonts:(BOOL)flag;
- (void)setFontCollectionName:(NSString *)collectionName;
- (NSString *)fontCollectionName;
- (void)setFontFamilyName:(NSString *)familyName;
- (NSString *)fontFamilyName;
- (MacOSaiXGlyphFontsType)fontsType;

- (void)setColorListName:(NSString *)listName ofClass:(NSString *)listClass;
- (NSString *)colorListName;
- (NSString *)colorListClass;

- (void)setLetterPool:(NSString *)pool;
- (NSString *)letterPool;

- (void)setAspectRatio:(NSNumber *)ratio;
- (NSNumber *)aspectRatio;

@end

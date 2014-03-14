//
//  MacOSaiXSourceImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on 2/11/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageSource.h"

@class MacOSaiXBitmapImageRep;


@interface MacOSaiXSourceImage : NSObject
{
	NSImage					*image;
    id<MacOSaiXImageSource>	imageSource;
	NSString				*imageIdentifier;
	
	NSString				*key;
	
	NSSize					imageSize;
}

+ (id)sourceImageWithImage:(NSImage *)image	
				identifier:(NSString *)identifier 
					source:(id<MacOSaiXImageSource>)source;

- (id)initWithImage:(NSImage *)inImage 
		 identifier:(NSString *)inImageIdentifier 
			 source:(id<MacOSaiXImageSource>)inImageSource;

- (void)setImage:(NSImage *)inImage;
- (NSImage *)image;
- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size;
- (NSSize)size;

- (id<MacOSaiXImageSource>)source;
- (NSString *)identifier;

- (NSComparisonResult)compare:(MacOSaiXSourceImage *)otherImage;

- (NSString *)key;
- (NSString *)description;
- (NSString *)debugDescription;
- (NSURL *)URL;
- (NSURL *)contextURL;

@end

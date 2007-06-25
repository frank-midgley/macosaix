//
//  MacOSaiXSourceImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXImageSourceEnumerator;


	// An image from an image source.
@interface MacOSaiXSourceImage : NSObject <NSCopying>
{
	NSImage							*image;
	NSString						*imageIdentifier;
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator;
}

+ (id)sourceImageWithImage:(NSImage *)inImage withIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;

- (id)initWithImage:(NSImage *)image withIdentifier:(NSString *)imageIdentifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;

- (NSImage *)image;
- (NSSize)nativeSize;

- (NSString *)imageIdentifier;
- (NSString *)universalIdentifier;
- (NSURL *)contextURL;

- (MacOSaiXImageSourceEnumerator *)enumerator;

- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size;

@end

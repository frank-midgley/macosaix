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
	NSString						*imageIdentifier;
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator;
}

+ (id)sourceImageWithIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;

- (id)initWithIdentifier:(NSString *)imageIdentifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;

- (NSSize)nativeSize;

- (NSString *)imageIdentifier;
- (id<NSObject,NSCoding,NSCopying>)universalIdentifier;
- (NSURL *)contextURL;

- (MacOSaiXImageSourceEnumerator *)enumerator;

- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size;

@end

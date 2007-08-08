//
//  MacOSaiXSourceImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@protocol MacOSaiXImageSource;


	// An image from an image source.
@interface MacOSaiXSourceImage : NSObject <NSCopying>
{
}

- (NSSize)nativeSize;

- (id<MacOSaiXImageSource>)imageSource;
- (Class)imageSourceClass;

- (NSString *)imageIdentifier;
- (id<NSObject,NSCoding,NSCopying>)universalIdentifier;
- (NSURL *)contextURL;

- (NSImage *)image;
- (NSImage *)thumbnailImage;
- (NSBitmapImageRep *)imageRepAtSize:(NSSize)size;

@end

//
//  MacOSaiXSourceImage.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSourceImage.h"

@class MacOSaiXImageSourceEnumerator;


	// An image from an image source.
@interface MacOSaiXEnumeratedImage : MacOSaiXSourceImage
{
	NSString						*imageIdentifier;
	MacOSaiXImageSourceEnumerator	*imageSourceEnumerator;
}

+ (id)imageWithIdentifier:(NSString *)identifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;

- (id)initWithIdentifier:(NSString *)imageIdentifier fromEnumerator:(MacOSaiXImageSourceEnumerator *)enumerator;

- (MacOSaiXImageSourceEnumerator *)enumerator;

@end

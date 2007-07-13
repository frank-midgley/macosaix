//
//  MacOSaiXImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Oct 16 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXPlugIn.h"


@protocol MacOSaiXImageSource <MacOSaiXDataSource>

	// Whether multiple sources of this type can be added to the same mosaic.
+ (BOOL)allowMultipleImageSources;

	// Return an image source configured so that it can return information for the indicated universal identifier.
+ (id<MacOSaiXImageSource>)imageSourceForUniversalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier;

	// The aspect ratio (width / height) of the images in this source.  If the ratio is not known or is variable then return nil.
- (NSNumber *)aspectRatio;

	// This method should return whether there are any images remaining in the source.
	// TBD: is this needed or is nil from -nextImageAndIdentifier: enough?
- (BOOL)hasMoreImages;

	// This method should return the number of images available from this source or nil if the count is not known.  The method will be called frequently so it should be relatively efficient and the returned count can be updated over time if needed.
- (NSNumber *)imageCount;

	// This method should return the next image along with a string that uniquely identifies the image, e.g. a path, URL, time index, etc.  If -canRefetchImages returns YES then the identifier will be passed to -imageForIdentifier: at a later time and must be able to return the same image.
- (NSImage *)nextImageAndIdentifier:(NSString **)identifier;

	// This method should return YES if -imageForIdentifier: can be called for strings returned by -nextImageAndIdentifier:.  If this method returns NO then the images returned by -nextImageAndIdentifier will be saved with the mosaic document.
- (BOOL)canRefetchImages;

	// This method should return an object that identifies the image indicated by identifier independently of the image source.  The object returned is typically an NSURL or NSString but any object conforming to NSCopying is allowed.
- (id<NSObject,NSCoding,NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier;

	// This method should return an object that identifies the image indicated by identifier independently of the image source.  The object returned is typically an NSURL or NSString but any object conforming to NSCopying is allowed.
- (NSString *)identifierForUniversalIdentifier:(id<NSCopying>)identifier;

	// This method should return the image specified by the identifier.  The identifier will always be one of the values returned by a previous call to -nextImageAndIdentifier:.  The image does not need to be the exact same instance returned by -nextImageAndIdentifier but should contain the same image data.
- (NSImage *)thumbnailForIdentifier:(NSString *)identifier;

	// This method should return the image specified by the identifier.  The identifier will always be one of the values returned by a previous call to -nextImageAndIdentifier:.  The image does not need to be the exact same instance returned by -nextImageAndIdentifier but should contain the same image data.
- (NSImage *)imageForIdentifier:(NSString *)identifier;

	// This method should return a URL that points to the identified image.  Return nil if there is no appropriate URL.
- (NSURL *)urlForIdentifier:(NSString *)identifier;

	// This method should return a URL that points to a web page that describes the image.  Return nil if there is no appropriate URL.
- (NSURL *)contextURLForIdentifier:(NSString *)identifier;

	// This method should return a string that describes the image.  Return nil if there is no description currently available.
- (NSString *)descriptionForIdentifier:(NSString *)identifier;

	// This method will be called whenever the user modifies a mosaic's tiles setup or modifies the settings of this source.  The image source should set the image count back to zero and, if appropriate, start over.
- (void)reset;

- (BOOL)imagesShouldBeRemovedForLastChange;

@end

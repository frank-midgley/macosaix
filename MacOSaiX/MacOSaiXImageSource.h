//
//  MacOSaiXImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Oct 16 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MacOSaiXImageSource <NSObject, NSCopying>

// TBD: initWithXML?

	// Name to display in image source pop-up menu
+ (NSString *)name;

+ (Class)editorClass;

	// Whether multiple sources of this type can be added (maybe glyphs?)
+ (BOOL)allowMultipleImageSources;

	// This method should return whether or not this source can
- (NSImage *)image;
- (id)descriptor;	// either an NSString or an NSAttributedString

	// This method should return whether there are any images remaining in the source.
	// TBD: is this needed or is nil from -nextImageAndIdentifier: enough?
- (BOOL)hasMoreImages;

	// This method should return the next image along with an identifier if images can be refetched
	// using -imageForIdentifier:.  The identifier should uniquely identify the image by storing a
	// path, URL, time index, etc. in the string.  If images cannot be refetched then identifier
	// should be set to nil.
- (NSImage *)nextImageAndIdentifier:(NSString **)identifier;

	// This method should return the image specified by the identifier.  The identifier will always
	// be one of the values returned by a previous call to -nextImageAndIdentifier:.
- (NSImage *)imageForIdentifier:(NSString *)identifier;

	// This method will be called whenever the user modifies a mosaic's tiles setup or
	// modifies the settings of this source.  The image source should set the image
	// count back to zero and, if appropriate, start over.
- (void)reset;

// TBD: saveXML?

@end


@protocol MacOSaiXImageSourceController <NSObject>

	// The view to insert into the drawer
- (NSView *)imageSourceView;

- (void)setOKButton:(NSButton *)button;

- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource;

@end

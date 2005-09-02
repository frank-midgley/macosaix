//
//  MacOSaiXImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Oct 16 2004.
//  Copyright (c) 2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define kMacOSaiXImageSourceSettingType @"Element Type"
#define kMacOSaiXImageSourceSettingText @"Element Text"


@protocol MacOSaiXImageSource <NSObject, NSCopying>

	// Name to display in image source pop-up menu
+ (NSString *)name;

	// The image for a generic source of this type.
+ (NSImage *)image;

+ (Class)editorClass;

	// Whether multiple sources of this type can be added (maybe glyphs?)
+ (BOOL)allowMultipleImageSources;

	// Methods for adding settings to a saved file.
- (NSString *)settingsAsXMLElement;

	// Methods called when loading settings from a saved mosaic.
- (void)useSavedSetting:(NSDictionary *)settingDict;
- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict;
- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict;

	// An image representing this specific source (may be the same as +image)
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

	// The view to use for editing an image source.
- (NSView *)editorView;
- (NSSize)editorViewMinimumSize;
- (NSResponder *)editorViewFirstResponder;

- (void)setOKButton:(NSButton *)button;

- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource;

@end

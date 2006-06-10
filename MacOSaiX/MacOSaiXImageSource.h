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

	// The image for a generic source of this type.
+ (NSImage *)image;

+ (Class)editorClass;

+ (Class)preferencesControllerClass;

	// Whether multiple sources of this type can be added (maybe glyphs?)
+ (BOOL)allowMultipleImageSources;

	// Methods for adding settings to a saved file.
- (NSString *)settingsAsXMLElement;

	// Methods called when loading settings from a saved mosaic.
- (void)useSavedSetting:(NSDictionary *)settingDict;
- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict;
- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict;

	// An image representing this specific source (may be the same image returned by +image)
- (NSImage *)image;

- (id)descriptor;	// either an NSString or an NSAttributedString

	// The aspect ratio (width / height) of the images in this source.  If the ratio is not known 
	// or is variable then return 0.0.
- (float)aspectRatio;

	// This method should return whether there are any images remaining in the source.
	// TBD: is this needed or is nil from -nextImageAndIdentifier: enough?
- (BOOL)hasMoreImages;

	// This method should return the next image along with a string that uniquely identifies the image, 
	// e.g. a path, URL, time index, etc.  If -canRefetchImages returns YES then the identifier will be 
	// passed to -imageForIdentifier: at a later time and must be able to return the same image.
- (NSImage *)nextImageAndIdentifier:(NSString **)identifier;

	// This method should return YES if -imageForIdentifier: can be called for strings returned by 
	// -nextImageAndIdentifier:.  If this method returns NO then the images returned by 
	// -nextImageAndIdentifier will be saved with the mosaic document.
- (BOOL)canRefetchImages;

	// This method should return the image specified by the identifier.  The identifier will always
	// be one of the values returned by a previous call to -nextImageAndIdentifier:.  The image does 
	// not need to be the exact same instance returned by -nextImageAndIdentifier but should contain  
	// the same image data.
- (NSImage *)thumbnailForIdentifier:(NSString *)identifier;

	// This method should return the image specified by the identifier.  The identifier will always
	// be one of the values returned by a previous call to -nextImageAndIdentifier:.  The image does 
	// not need to be the exact same instance returned by -nextImageAndIdentifier but should contain  
	// the same image data.
- (NSImage *)imageForIdentifier:(NSString *)identifier;

	// This method should return a URL that points to the identified image.
	// Return nil if there is no appropirate URL.
- (NSURL *)urlForIdentifier:(NSString *)identifier;

	// This method should return a URL that points to a web page that describes the image.
	// Return nil if there is no appropriate URL.
- (NSURL *)contextURLForIdentifier:(NSString *)identifier;

	// This method should return a URL that points to a web page that describes the image.
	// Return nil if there is no description currently available.
- (NSString *)descriptionForIdentifier:(NSString *)identifier;

	// This method will be called whenever the user modifies a mosaic's tiles setup or
	// modifies the settings of this source.  The image source should set the image
	// count back to zero and, if appropriate, start over.
- (void)reset;

@end


@protocol MacOSaiXImageSourceController <NSObject>

	// This method should return the view used to edit an image source.
- (NSView *)editorView;

	// These methods should return the minimum and maximum sizes of the editor view.
	// If no limit is desired then return NSZeroSize from either method.
- (NSSize)minimumSize;
- (NSSize)maximumSize;

	// This method should return the control of the editor view that should initially receive focus.
- (NSResponder *)firstResponder;

	// This method is called whenever an image source is to be edited.  The controller 
	// should populate its controls with the values from the image source and update the 
	// source when the user makes changes to the controls.
- (void)editImageSource:(id<MacOSaiXImageSource>)imageSource;

	// This method should indicate whether the current state of the editing controls 
	// represents a valid image source.  If NO then the OK button will be disabled.
- (BOOL)settingsAreValid;

- (void)editingComplete;

@end

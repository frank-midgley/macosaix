//
//  DirectoryImageSourceDirectory.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/24/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@interface DirectoryImageSourceDirectory : NSObject
{
	NSString			*directoryPath, 
						*displayName, 
						*locationDisplayName;
	NSImage				*icon, 
						*locationIcon;
	NSAttributedString	*attributedLocation;
	int					imageCount;
}

+ (DirectoryImageSourceDirectory *)directoryWithPath:(NSString *)path imageCount:(int)count;
- (id)initWithPath:(NSString *)path imageCount:(int)count;

- (void)setPath:(NSString *)path;
- (NSString *)path;

- (void)setImageCount:(int)count;
- (int)imageCount;

- (NSString *)displayName;

- (NSImage *)icon;

- (NSAttributedString *)locationAttributedPath;
- (NSString *)locationDisplayName;
- (NSImage *)locationIcon;

@end

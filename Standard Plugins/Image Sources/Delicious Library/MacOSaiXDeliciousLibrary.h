//
//  MacOSaiXDeliciousLibrary.h
//  MacOSaiX
//
//  Created by Frank Midgley on 3/15/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXDLItem, MacOSaiXDLItemType, MacOSaiXDLShelf;


extern NSString	*MacOSaiXDLDidChangeStateNotification;


@interface MacOSaiXDeliciousLibrary : NSObject
{
	BOOL				isInstalled;
	
	NSMutableDictionary	*shelves, 
						*allItems, 
						*typeImages;
	NSMutableArray		*itemTypes;
	
	NSImage				*deliciousLibraryImage, 
						*shelfImage, 
						*smartShelfImage;
	
		// Parsing support
	BOOL				isLoading;
	NSError				*loadingError;
	MacOSaiXDLShelf		*currentShelf;
	BOOL				inRecommendations;
}

+ (MacOSaiXDeliciousLibrary *)sharedLibrary;

- (NSImage *)image;
- (NSImage *)shelfImage;
- (NSImage *)smartShelfImage;

- (void)loadLibrary;
- (BOOL)isLoading;
- (NSError *)loadingError;

- (BOOL)isInstalled;

- (NSArray *)shelves;
- (MacOSaiXDLShelf *)shelfWithUUID:(NSString *)title;

- (NSArray *)itemTypes;
- (NSImage *)imageOfType:(OSType)type;
- (MacOSaiXDLItemType *)itemTypeWithType:(OSType)type;

- (NSArray *)allItems;
- (MacOSaiXDLItem *)itemWithUUID:(NSString *)itemUUID;

@end

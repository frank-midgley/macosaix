//
//  MacOSaiXDLItemType.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/2/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXDLItem;


@interface MacOSaiXDLItemType : NSObject
{
	OSType			type;
	NSString		*name;
	NSImage			*image;
	NSMutableArray	*items;
}

- (id)initWithType:(OSType)type;

- (OSType)type;
- (NSString *)name;
- (NSImage *)image;

- (void)addItem:(MacOSaiXDLItem *)item;
- (NSArray *)items;

@end

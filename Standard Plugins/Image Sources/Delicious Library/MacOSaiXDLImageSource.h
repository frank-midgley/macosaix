/*
	MacOSaiXDLImageSource.h
	MacOSaiX

	Created by Frank Midgley on Sat Mar 15 2008.
	Copyright (c) 2008 Frank M. Midgley. All rights reserved.
*/

#import <Cocoa/Cocoa.h>

#import "MacOSaiXImageSource.h"

@class MacOSaiXDLItemType, MacOSaiXDLShelf;


@interface MacOSaiXDLImageSource : NSObject <MacOSaiXImageSource>
{
	MacOSaiXDLItemType	*itemType;
	MacOSaiXDLShelf		*shelf;
	
	NSString			*descriptor;
	
	NSMutableArray		*queuedItems;
}

- (void)setItemType:(MacOSaiXDLItemType *)type;
- (MacOSaiXDLItemType *)itemType;

- (void)setShelf:(MacOSaiXDLShelf *)shelf;
- (MacOSaiXDLShelf *)shelf;

@end

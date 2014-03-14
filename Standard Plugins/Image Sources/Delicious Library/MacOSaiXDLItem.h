//
//  MacOSaiXDLItem.h
//  MacOSaiX
//
//  Created by Frank Midgley on 3/15/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXDLItemType;


@interface MacOSaiXDLItem : NSObject
{
	MacOSaiXDLItemType	*type;
	NSString			*title, 
						*UUID, 
						*ASIN;
	NSURL				*coverURL;
}

+ (MacOSaiXDLItem *)itemWithType:(MacOSaiXDLItemType *)type 
						   title:(NSString *)title 
							UUID:(NSString *)UUID 
							ASIN:(NSString *)identificationNumber;

- (id)initWithType:(MacOSaiXDLItemType *)type 
			 title:(NSString *)title 
			  UUID:(NSString *)UUID 
			  ASIN:(NSString *)identificationNumber;

- (void)setCoverURL:(NSURL *)coverURL;
- (NSURL *)coverURL;

- (MacOSaiXDLItemType *)type;
- (NSString *)title;
- (NSString *)UUID;
- (NSString *)ASIN;

- (NSComparisonResult)compareTitle:(id)otherObject;

- (NSImage *)image;

@end

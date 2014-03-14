//
//  MacOSaiXDLItemType.m
//  MacOSaiX
//
//  Created by Frank Midgley on 4/2/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXDLItemType.h"

#import "MacOSaiXDeliciousLibrary.h"


@implementation MacOSaiXDLItemType


- (id)initWithType:(OSType)inType
{
	if (self = [super init])
	{
		type = inType;
		items = [[NSMutableArray alloc] init];
		
		if (type == 'CL07')
			name = @"apparel";
		else if (type == 'B00K')
			name = @"books";
		else if (type == '3LCT')
			name = @"gadgets";
		else if (type == 'M0VE')
			name = @"movies";
		else if (type == 'MUS3')
			name = @"music";
		else if (type == 'WR3Z')
			name = @"software";
		else if (type == 'T00L')
			name = @"tools";
		else if (type == 'AT0Y')
			name = @"toys";
		else if (type == 'V1DE')
			name = @"video games";
		else
			name = @"items";
	}
	
	return self;
}


- (OSType)type
{
	return type;
}


- (NSString *)name
{
	return name;
}


- (NSImage *)image
{
	return [[MacOSaiXDeliciousLibrary sharedLibrary] imageOfType:type];
}


- (void)addItem:(MacOSaiXDLItem *)item
{
	[items addObject:item];
}


- (NSArray *)items
{
	return [NSArray arrayWithArray:items];
}


- (NSComparisonResult)compare:(id)otherObject
{
	return [name compare:[otherObject name]];
}


- (void)dealloc
{
	[items release];
	
	[super dealloc];
}


@end

//
//  TilesSetupController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface TilesSetupController : NSWindowController
{
	@private
		void			*_MacOSaiX_reserved1,	// reserve some space for future needs
						*_MacOSaiX_reserved2,
						*_MacOSaiX_reserved3,
						*_MacOSaiX_reserved4;
	@public
		IBOutlet NSView	*_setupView;
}

+ (NSString *)name;
- (NSView *)setupView;
- (void)setTileOutlines:(NSArray *)outlines;


@end

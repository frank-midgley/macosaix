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
	IBOutlet NSView	*_setupView;
}

- (NSView *)setupView;

@end

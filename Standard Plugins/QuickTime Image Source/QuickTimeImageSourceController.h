//
//  QuickTimeImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MacOSaiXPlugIns/ImageSourceController.h>


@interface QuickTimeImageSourceController : ImageSourceController
{
	IBOutlet NSTextField	*_pathField;
	IBOutlet NSButton		*_okButton;
}

- (void)chooseMovie:(id)sender;
- (void)chooseMovieDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context;

@end

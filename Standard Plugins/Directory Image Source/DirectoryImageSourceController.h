//
//  DirectoryImageSourceController.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Mar 08 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MacOSaiXPlugIns/ImageSourceController.h>


@interface DirectoryImageSourceController : ImageSourceController
{
	IBOutlet NSTextField	*_pathField;
	IBOutlet NSButton		*_okButton;
}

- (void)chooseDirectory:(id)sender;
- (void)chooseDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)context;

@end

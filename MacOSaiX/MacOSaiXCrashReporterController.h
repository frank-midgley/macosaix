//
//  MacOSaiXCrashReporterController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXCrashReporterController : NSWindowController
{
	IBOutlet NSTextField	*crashDescriptionField,
							*emailAddressField;
	IBOutlet NSButton		*detailsButton;
	IBOutlet NSBox			*detailsBox;
	IBOutlet NSTextField	*memoryField,
							*processorCountField;
	IBOutlet NSTableView	*plugInsTable;
	IBOutlet NSTextView		*crashLogTextView;
	IBOutlet NSButton		*submitReportButton,
							*cancelReportButton;
}

+ (void)checkForCrash;

- (IBAction)toggleReportDetails:(id)sender;

- (IBAction)cancelReport:(id)sender;
- (IBAction)submitReport:(id)sender;

@end

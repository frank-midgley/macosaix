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
	NSString						*crashLog;
	NSDate							*crashDate;
	
	IBOutlet NSTextField			*crashDescriptionField,
									*emailAddressField;
	IBOutlet NSButton				*detailsButton;
	IBOutlet NSBox					*detailsBox;
	IBOutlet NSTextField			*memoryField,
									*processorField;
	IBOutlet NSTableView			*plugInsTable;
	IBOutlet NSTextView				*crashLogTextView;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSButton				*submitReportButton,
									*cancelReportButton;
	
	NSSize							defaultWindowMinSize,
									defaultWindowMaxSize;
	unsigned int					detailsBoxAutoresizeMask;
	float							detailsBoxWidthDiff;
	
	NSMutableArray					*plugIns;
}

+ (void)checkForCrash;

- (id)initWithCrashLog:(NSString *)crashLog crashDate:(NSDate *)crashDate;

- (IBAction)toggleReportDetails:(id)sender;

- (IBAction)cancelReport:(id)sender;
- (IBAction)submitReport:(id)sender;

@end

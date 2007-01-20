//
//  MacOSaiXCrashReporterController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXCrashReporterController.h"

#import "MacOSaiX.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXImageSource.h"

#import <sys/sysctl.h>


@implementation MacOSaiXCrashReporterController


+ (void)checkForCrash
{
	NSDate		*lastKnownCrashDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Known Crash"];
	if (!lastKnownCrashDate)
		lastKnownCrashDate = [NSDate dateWithNaturalLanguageString:@"2005/09/01"];
	
	NSString	*crashLogPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/CrashReporter/MacOSaiX.crash.log"];
	NSArray		*crashLogs = [[NSString stringWithContentsOfFile:crashLogPath] componentsSeparatedByString:@"\n**********\n\n"];
	NSString	*mostRecentCrash = [crashLogs lastObject];
	
	if (mostRecentCrash)
	{
		NSScanner	*dateScanner = [NSScanner scannerWithString:mostRecentCrash];
		NSString	*mostRecentCrashDateString = nil;
		
		if ([dateScanner scanUpToString:@"Date/Time:" intoString:nil] && 
			[dateScanner scanString:@"Date/Time:" intoString:nil] && 
			[dateScanner scanUpToString:@"\n" intoString:&mostRecentCrashDateString])
		{
			NSCalendarDate	*mostRecentCrashDate = [NSCalendarDate dateWithString:mostRecentCrashDateString
																   calendarFormat:@"%Y-%m-%d %H:%M:%S.%F %z"];
			if ([lastKnownCrashDate compare:mostRecentCrashDate] == NSOrderedAscending)
			{
				MacOSaiXCrashReporterController	*controller = [[self alloc] initWithCrashLog:mostRecentCrash 
																				   crashDate:mostRecentCrashDate];
				
				[controller showWindow:self];
			}
		}
	}
}


- (id)initWithCrashLog:(NSString *)inCrashLog crashDate:(NSDate *)inCrashDate
{
	if (self = [super initWithWindow:nil])
	{
		crashLog = [inCrashLog retain];
		crashDate= [inCrashDate retain];
	}
	
	return self;
}


- (NSString *)windowNibName
{
	return @"Crash Reporter";
}


- (void)awakeFromNib
{
	defaultWindowMinSize = [[self window] minSize];
	defaultWindowMaxSize = [[self window] maxSize];
	[detailsBox retain];
	detailsBoxAutoresizeMask = [detailsBox autoresizingMask];
	detailsBoxWidthDiff = NSWidth([[self window] frame]) - NSWidth([detailsBox frame]);
	
		// Show the amount of physical memory installed.
	unsigned	memorySize = NSRealMemoryAvailable();
	if (memorySize < 1 * 1024 * 1024 * 1024)
		[memoryField setStringValue:[NSString stringWithFormat:@"%d MB", memorySize / (1024 * 1024)]];
	else
		[memoryField setStringValue:[NSString stringWithFormat:@"%.1f GB", (float)memorySize / (1024.0 * 1024.0 * 1024.0)]];
		
		// Show the count and type of CPU(s)
	int			numCPU = 0;
	NSString	*cpuCount = @"",
				*cpuType = @"Unknown",
				*cpuSubType = @"";
	size_t		intSize = sizeof(numCPU);
	if (sysctlbyname("hw.ncpu", &numCPU, &intSize, NULL, 0) == 0)
	{
		if (numCPU == 2)
			cpuCount = @"Dual ";
		else if (numCPU == 3)
			cpuCount = @"Triple ";
		else if (numCPU == 4)
			cpuCount = @"Quad ";
		else if (numCPU > 4)
			cpuCount = @"Multiple ";
	}
	
	int			type;
	intSize = sizeof(type);
	if (sysctlbyname("hw.cputype", &type, &intSize, NULL, 0) == 0)
	{
		switch (type)
		{
			case CPU_TYPE_I386:		cpuType = @"i386";		break;
			case CPU_TYPE_POWERPC:	cpuType = @"PowerPC";	break;
			default:				break;
		}
		
		intSize = sizeof(type);
		if (sysctlbyname("hw.cpusubtype", &type, &intSize, NULL, 0) == 0)
		{
			switch (type)
			{
				case CPU_SUBTYPE_POWERPC_7400:
				case CPU_SUBTYPE_POWERPC_7450:	cpuSubType = @" G4";	break;
				case CPU_SUBTYPE_POWERPC_970:	cpuSubType = @" G5";	break;
				default:						break;
			}
		}
	}
	
	[processorField setStringValue:[NSString stringWithFormat:@"%@%@%@", cpuCount, cpuType, cpuSubType]];
	
		// Build the data source for the plug-ins table.
	plugIns = [[NSMutableArray array] retain];
	MacOSaiX		*appDelegate = [NSApp delegate];
	NSArray			*plugInClasses = [appDelegate allPlugIns];
	NSEnumerator	*plugInClassEnumerator = [plugInClasses objectEnumerator];
	Class			plugInClass = nil;
	while ((plugInClass = [plugInClassEnumerator nextObject]))
	{
		NSBundle	*plugInBundle = [NSBundle bundleForClass:plugInClass];
		NSString	*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"], 
					*plugInVersion = [plugInBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		
		if ([plugInClass conformsToProtocol:@protocol(MacOSaiXTileShapes)])
			[plugIns addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												@"Tile Shapes", @"Type", 
												plugInName, @"Name", 
												plugInVersion, @"Version", 
												nil]];
		else if ([plugInClass conformsToProtocol:@protocol(MacOSaiXImageSource)])
			[plugIns addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												@"Image Source", @"Type", 
												plugInName, @"Name", 
												plugInVersion, @"Version", 
												nil]];
	}
	[plugInsTable reloadData];
	
	[crashLogTextView setString:crashLog];
	
		// Start off with the details hidden.
	[detailsButton setState:NSOffState];
	[self toggleReportDetails:self];
}


- (IBAction)toggleReportDetails:(id)sender
{
	float	heightChange = NSHeight([detailsBox frame]);
	
	if ([detailsButton state] == NSOffState)
	{
			// Hide the details
		[detailsBox removeFromSuperview];
		
		NSRect			newWindowFrame = NSOffsetRect([[self window] frame], 0.0, heightChange);
		newWindowFrame.size.height -= heightChange;
		[[self window] setFrame:newWindowFrame display:YES animate:NO];
		
		[[self window] setMinSize:NSMakeSize(defaultWindowMinSize.width, NSHeight(newWindowFrame))];
		[[self window] setMaxSize:NSMakeSize(defaultWindowMaxSize.width, NSHeight(newWindowFrame))];
	}
	else
	{
			// Show the details
		NSRect			newWindowFrame = NSOffsetRect([[self window] frame], 0.0, -heightChange);
		newWindowFrame.size.height += heightChange;
		[[self window] setFrame:newWindowFrame display:YES animate:NO];

		[[self window] setMinSize:defaultWindowMinSize];
		[[self window] setMaxSize:defaultWindowMaxSize];
		
		NSRect			newDetailsFrame = [detailsBox frame];
		newDetailsFrame.size.width = newWindowFrame.size.width - detailsBoxWidthDiff;
		[detailsBox setFrame:newDetailsFrame];
		[[[self window] contentView] addSubview:detailsBox];
	}
}


- (IBAction)cancelReport:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:crashDate forKey:@"Last Known Crash"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self close];
}


- (IBAction)submitReport:(id)sender
{
	NSString	*crashDescription = ([[crashDescriptionField stringValue] length] > 0 ? [crashDescriptionField stringValue] : 
																						@"I can't remember what I was doing."), 
				*contactEmail = ([[emailAddressField stringValue] length] > 0 ? [emailAddressField stringValue] : 
																				@"Please don't contact me."), 
				*messageBody = [NSString stringWithFormat:@"Crash description: %@\n" \
														  @"Contact E-mail: %@\n" \
														  @"Memory: %@\n" \
														  @"CPU(s): %@\n\n" \
														  @"====================\n\n" \
														  @"Crash Log\n\n" \
														  @"%@" \
														  @"====================\n\n", 
														  crashDescription, 
														  contactEmail, 
														  [memoryField stringValue], 
														  [processorField stringValue], 
														  crashLog];
	CFStringRef	escapedMessage = CFURLCreateStringByAddingPercentEscapes(nil, (CFStringRef)messageBody, nil, nil, kCFStringEncodingUTF8);
	NSString	*urlString = [NSString stringWithFormat:@"mailto:knarf@mac.com?subject=MacOSaiX%%20Crash%%20Report&body=%@", escapedMessage];
	
	if ([[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]])
	{
		[[NSUserDefaults standardUserDefaults] setObject:crashDate forKey:@"Last Known Crash"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self close];
	}
	else
	{
			// Make sure the details are showing so they can copy and paste.
		if ([detailsButton state] == NSOffState)
		{
			[detailsButton setState:NSOnState];
			[self toggleReportDetails:self];
		}
		
		NSRunAlertPanel(@"MacOSaiX could not compose a crash report e-mail for you.", 
						@"Please copy and paste the crash log into an e-mail and send it to knarf@mac.com.", 
						@"OK", nil, nil);
	}
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [plugIns count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [[plugIns objectAtIndex:row] objectForKey:[tableColumn identifier]];
}


- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	[plugIns sortUsingDescriptors:[tableView sortDescriptors]];
	[tableView reloadData];
}


- (void)windowWillClose:(NSNotification *)notification
{
	[self autorelease];
}


- (void)dealloc
{
	[detailsBox release];
	[crashLog release];
	[crashDate release];
	[plugIns release];
	
	[super dealloc];
}


@end

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
	if (YES)
	{
		MacOSaiXCrashReporterController	*controller = [[self alloc] initWithWindow:nil];
		
		[controller showWindow:self];
	}
}


- (NSString *)windowNibName
{
	return @"Crash Reporter";
}


- (void)awakeFromNib
{
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
	[appDelegate discoverPlugIns];
	NSArray			*plugInClasses = [[appDelegate tileShapesClasses] arrayByAddingObjectsFromArray:[appDelegate imageSourceClasses]];
	NSEnumerator	*plugInClassEnumerator = [plugInClasses objectEnumerator];
	Class			plugInClass = nil;
	while ((plugInClass = [plugInClassEnumerator nextObject]))
	{
		NSString	*version = [[NSBundle bundleForClass:plugInClass] objectForInfoDictionaryKey:@"CFBundleVersion"];
		
		if ([plugInClass conformsToProtocol:@protocol(MacOSaiXTileShapes)])
			[plugIns addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												@"Tile Shapes", @"Type", 
												[plugInClass name], @"Name", 
												version, @"Version", 
												nil]];
		else if ([plugInClass conformsToProtocol:@protocol(MacOSaiXImageSource)])
			[plugIns addObject:[NSDictionary dictionaryWithObjectsAndKeys:
												@"Image Source", @"Type", 
												[plugInClass name], @"Name", 
												version, @"Version", 
												nil]];
	}
	[plugInsTable reloadData];
	
		// 
	NSString	*crashLogPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/CrashReporter/MacOSaiX.crash.log"];
	[crashLogTextView setString:[NSString stringWithContentsOfFile:crashLogPath]];
}


- (IBAction)toggleReportDetails:(id)sender
{
}


- (IBAction)cancelReport:(id)sender
{
}


- (IBAction)submitReport:(id)sender
{
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


- (void)dealloc
{
	[plugIns release];
	
	[super dealloc];
}


@end

//
//  MacOSaiXCrashReporterController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 6/22/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXCrashReporterController.h"

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
	[memoryField setIntValue:NSRealMemoryAvailable()];
	
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
	return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return nil;
}


@end

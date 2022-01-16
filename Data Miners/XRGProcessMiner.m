/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2022 Gaucho Software, LLC.
 * You can view the complete license in the LICENSE file in the root
 * of the source tree.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

#import "XRGProcessMiner.h"


@implementation XRGProcessMiner

- (void) graphUpdate:(NSTimer *)aTimer {
	// Init the task.
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/ps"];
	[task setArguments:@[@"axwwrco", @"%cpu,pid,rss,vsz,nswap,user,command"]];
	
	// Init the stdout pipe.
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	
	// Grab a filehandle for the stdout pipe.
	NSFileHandle *file = [pipe fileHandleForReading];
	
	// Launch the task.
	[task launch];
		
	// Get the output string from the file handle data.
	NSString *outputString = [[NSString alloc] initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	
	// Parse the output string.
	NSArray *outputLines = [outputString componentsSeparatedByString:@"\n"];
	NSMutableArray *newProcessArray = [NSMutableArray arrayWithCapacity:[outputLines count]];
	
	// For each line (excluding the first header line).
	for (int i = 1; i < [outputLines count]; i++) {
		NSString *line = outputLines[i];
		NSArray *lineComponents = [line componentsSeparatedByString:@" "];
		NSMutableArray *lineComponentsNoBlanks = [NSMutableArray arrayWithCapacity:[lineComponents count]];
		
		// Remove all the blank objects.
		int j;
		for (j = 0; j < [lineComponents count]; j++) {
			NSString *component = lineComponents[j];
			if ([component length] > 0) {
				[lineComponentsNoBlanks addObject:component];
			}
		}
		
		NSInteger numLineComponents = [lineComponentsNoBlanks count];
		if (numLineComponents >= 7) {
			
			NSString *percentCPUString     = lineComponentsNoBlanks[0];
			NSString *pid                  = lineComponentsNoBlanks[1];
			NSString *rssString            = lineComponentsNoBlanks[2];
			NSString *vssString            = lineComponentsNoBlanks[3];
			NSString *nswapString          = lineComponentsNoBlanks[4];
			NSString *userString           = lineComponentsNoBlanks[5];
			NSMutableString *commandString = [NSMutableString stringWithString:lineComponentsNoBlanks[6]];
			for (j = 7; j < numLineComponents; j++) {
				[commandString appendFormat:@" %@", lineComponentsNoBlanks[j]];
			}
			if ([nswapString isEqualToString:@"-"]) nswapString = @"0";
			
			NSDictionary *d = @{ XRGProcessCommand: commandString,
								 XRGProcessPercentCPU: @([percentCPUString floatValue]),
								 XRGProcessID: @([pid intValue]),
								 XRGProcessResidentMemorySize: @([rssString intValue]),
								 XRGProcessVirtualMemorySize: @([vssString intValue]),
								 XRGProcessTotalSwaps: @([nswapString intValue]),
								 XRGProcessUser: userString };
			
			[newProcessArray addObject:d];
		}
	}
	
	[self setProcesses:newProcessArray];
}

- (NSArray *) processesSortedByCPUUsage {
	NSSortDescriptor *cpuSorter = [[NSSortDescriptor alloc] initWithKey:XRGProcessPercentCPU ascending:NO selector:@selector(compare:)];
	return [self.processes sortedArrayUsingDescriptors:@[cpuSorter]];
}

- (NSArray *) processesSortedByMemoryUsage {
	NSSortDescriptor *memorySorter = [[NSSortDescriptor alloc] initWithKey:XRGProcessResidentMemorySize ascending:NO selector:@selector(compare:)];
	return [self.processes sortedArrayUsingDescriptors:@[memorySorter]];
}

@end

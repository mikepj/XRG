/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2012 Gaucho Software, LLC.
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

//
//  XRGCPUView.m
//

#import "XRGGraphWindow.h"
#import "XRGCPUView.h"

#import <stdio.h>

@implementation XRGCPUView

- (void)awakeFromNib {   
    parentWindow = (XRGGraphWindow *)[self window];
    [parentWindow setCpuView:self];
    [parentWindow initTimers];
    
    appSettings = [parentWindow appSettings];
    moduleManager = [parentWindow moduleManager];
    
    CPUMiner = [[XRGCPUMiner alloc] init];
	processMiner = [[XRGProcessMiner alloc] init];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];    
    m = [[XRGModule alloc] initWithName:@"CPU" andReference:self];
    m.doesFastUpdate = YES;
    m.doesGraphUpdate = YES;
    m.doesMin5Update = NO;
    m.doesMin30Update = NO;
    m.displayOrder = 0;
    [self updateMinSize];
    [m setIsDisplayed: (bool)[defs boolForKey:XRG_showCPUGraph]];

    [[parentWindow moduleManager] addModule:m];
    [self setGraphSize:[m currentSize]];
}

- (void)setGraphSize:(NSSize)newSize {
    NSSize tmpSize;
    tmpSize.width = newSize.width;
    tmpSize.height = newSize.height;
    if (tmpSize.width < 8) tmpSize.width = 8;
    if (tmpSize.width > 2000) tmpSize.width = 2000;
    [self setWidth: tmpSize.width];
    graphSize = tmpSize;
    
    // Recalculate the fast cpu display rect for speed optimization.
    fastCPUDisplayRect = NSMakeRect(graphSize.width - 7, 0, 7, graphSize.height);
}

- (void)setWidth:(int)newWidth {
    int newNumSamples = newWidth;
    if ([appSettings fastCPUUsage]) 
        newNumSamples -= 7;

    if (newNumSamples < 0) return;

    [CPUMiner setDataSize:newNumSamples];

    numSamples  = newNumSamples;
}

- (void)updateMinSize {
    float width, height;
    height = [appSettings textRectHeight];
        
    int offset = [appSettings fastCPUUsage] ? 7 : 0;
    
    UPTIME_WIDE = [@"Uptime: 99d 23:59" sizeWithAttributes:[appSettings alignRightAttributes]].width + offset + 6;
    UPTIME_NORMAL = [@"U: 99d 23:59" sizeWithAttributes:[appSettings alignRightAttributes]].width + offset + 6;
    
    if ([CPUMiner numberOfCPUs] == 2) {
        AVG_WIDE = [@"99.9% Average 99.9%" sizeWithAttributes:[appSettings alignRightAttributes]].width + offset + 6;
        AVG_NORMAL = [@"99.9% Avg 99.9%" sizeWithAttributes:[appSettings alignRightAttributes]].width + offset + 6;

        width = [@"100% CPU 100%" sizeWithAttributes:[appSettings alignRightAttributes]].width + offset + 6;
    }
    else {  // this takes > 2 CPUs too, at the risk of displaying incorrectly (if Apple ever uses > 2 CPUs :-))
        AVG_WIDE = [@"Average: 99.9%" sizeWithAttributes:[appSettings alignRightAttributes]].width + offset + 6;
        AVG_NORMAL = [@"Avg: 99.9%" sizeWithAttributes:[appSettings alignRightAttributes]].width + offset + 6;

        width = UPTIME_NORMAL;
    }
    

    [m setMinWidth: width];
    [m setMinHeight: height];
}

- (void)graphUpdate:(NSTimer *)aTimer {
    [CPUMiner setLoadAverage:[appSettings showLoadAverage]];
    [CPUMiner setUptime:YES];
    [CPUMiner graphUpdate:aTimer];
    
    [self setNeedsDisplay:YES];
}

- (void)fastUpdate:(NSTimer *)aTimer {
	if ([CPUMiner numberOfCPUs] > 2 || [appSettings fastCPUUsage]) {
        [CPUMiner fastUpdate:aTimer];

		[self setNeedsDisplay:YES];
	}
}

- (void)drawRect:(NSRect)dummy
{
    NSRect inRect = NSMakeRect(0, 0, graphSize.width, graphSize.height);

	if ([CPUMiner numberOfCPUs] > 2) 
		[self drawLotsOfCoresGraph:inRect];
	else
		[self drawGraph:inRect];
    
    // Draw the graph in the application dock icon
    // Re-drawing uses about 2% of the CPU, and the drawing gets messed up if the graph window is higher res
    // than the icon.
    /*
    NSImage *currentAppImage = [NSImage imageNamed:@"NSApplicationIcon"];
    NSImage *newImage = [[NSImage alloc] initWithSize:[currentAppImage size]];
    [newImage lockFocus];
    inRect.size.width = [currentAppImage size].width;
    inRect.size.height = [currentAppImage size].height;
    
    [self drawGraph:inRect];
    
    [newImage unlockFocus];
    [NSApp setApplicationIconImage:newImage];   
    [newImage release]; 
    */
    
    // Capturing the current view and setting that as the dock icon uses ~.5% of the CPU, but skews if the
    // rect isn't a perfect square
    /*
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[self bounds]];
    NSImage *newImage = [[NSImage alloc] initWithSize:[bitmap size]];
    [newImage addRepresentation:bitmap];
    
    [NSApp setApplicationIconImage:newImage];   
    [newImage release];     
    [bitmap release];
    */
}

- (void)drawLotsOfCoresGraph:(NSRect)inRect {
    if ([self isHidden]) {
        return;
    }
	
    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 
	
    int i;
    float textRectHeight = [appSettings textRectHeight];
	
    NSRect textRect = NSMakeRect(3, inRect.size.height - textRectHeight, inRect.size.width - 6, textRectHeight);
	
    [gc setShouldAntialias:[appSettings antiAliasing]];
	
    [[appSettings graphBGColor] set];
    NSRectFill(inRect);
    
    NSInteger numCPUs = [CPUMiner numberOfCPUs];
	if (numCPUs == 0) return;
    
    if ([appSettings fastCPUUsage]) {
        // draw the divider line
        [[appSettings borderColor] set];
        NSRectFill(NSMakeRect(inRect.size.width - 7, 0, 2, inRect.size.height));
		
        // draw the fast cpu info
        [[appSettings graphFG2Color] set];
        NSInteger tmp = 0;
        NSInteger *fastValues = [CPUMiner fastValues];
        for (i = 0; i < numCPUs; i++) {
            tmp += fastValues[i];
        }
        
        NSRectFill(NSMakeRect(inRect.size.width - 7 + 2, 0, 5, ((float)tmp / (float)numCPUs) / 100. * graphSize.height));
	}
	
    // this is the rect that we will draw the graphs in
    if ([appSettings fastCPUUsage]) inRect.size.width -= 7;
    NSRect graphRect = NSMakeRect(0.0f, 0.0f, inRect.size.width, inRect.size.height);
	
    NSColor *colors[3];
    colors[0] = [appSettings graphFG1Color];
    colors[1] = [appSettings graphFG2Color];
    colors[2] = [appSettings graphFG3Color];
	
    graphRect.size.height = graphRect.size.height / 2. - 1.;
	
	// Draw the bottom graph.
	NSInteger *fastValues = [CPUMiner fastValues];
	NSMutableArray *sortedValues = [NSMutableArray arrayWithCapacity:numCPUs];
	for (i = 0; i < numCPUs; i++) {
		[sortedValues addObject:@(fastValues[i])];
	}
	[sortedValues sortUsingSelector:@selector(compare:)];
	sortedValues = [NSMutableArray arrayWithArray:[[sortedValues reverseObjectEnumerator] allObjects]];
	NSRect cpuRect = graphRect;
	cpuRect.size.width /= numCPUs;
	
	[[appSettings graphFG1Color] set];
	for (i = 0; i < numCPUs; i++) {
		NSRectFill(NSMakeRect(cpuRect.origin.x, cpuRect.origin.y, (int)(cpuRect.size.width - 1), [sortedValues[i] floatValue] / 100. * cpuRect.size.height));
		cpuRect.origin.x += cpuRect.size.width;
	}
	    	
#ifdef XRG_DEBUG
	NSLog(@"In CPU DrawRect."); 
#endif
    
	// Draw the top graph.
	graphRect.origin.y += graphRect.size.height + 1.;
	
	NSArray *cpuData = [CPUMiner combinedData];
	if ([cpuData count] < 3) return;
	// Create a tmpDataSet of the same size as the other ones so we can do some manipulations.
	XRGDataSet *tmpDataSet = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:cpuData[0]];
	[tmpDataSet addOtherDataSetValues:cpuData[1]];
	[tmpDataSet addOtherDataSetValues:cpuData[2]];
	if ([appSettings separateCPUColor]) {
		[self drawGraphWithDataFromDataSet:tmpDataSet maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[2]];
		
		[tmpDataSet subtractOtherDataSetValues:cpuData[2]];    
		[self drawGraphWithDataFromDataSet:tmpDataSet maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[1]];
		
		[self drawGraphWithDataFromDataSet:cpuData[0] maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[0]];
	}
	else {    
		[self drawGraphWithDataFromDataSet:tmpDataSet maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[0]];
	}
	
    // draw the text
    [gc setShouldAntialias:YES];
    [gc setShouldAntialias:[appSettings antialiasText]];
	
    if ([appSettings fastCPUUsage]) {
        textRect.size.width -= 7;
    }
	
    NSMutableString *leftText = [[NSMutableString alloc] init];
    NSMutableString *rightText = [[NSMutableString alloc] init];
    NSMutableString *centerText = [[NSMutableString alloc] init];
	
    textRect.origin.y = inRect.size.height - textRectHeight;
	
	// Draw the first line with the label and current CPU usage
	[leftText setString:@"CPU"];
	[rightText appendFormat:@"%3.f%%", MAX(0, ([(XRGDataSet *)cpuData[0] currentValue] + [(XRGDataSet *)cpuData[1] currentValue] + [(XRGDataSet *)cpuData[2] currentValue])) * [CPUMiner numberOfCPUs]];
	
	// draw the average usage text
	if ([appSettings cpuShowAverageUsage]) {
		if (textRect.origin.y - textRectHeight >= 0) {
			textRect.origin.y -= textRectHeight;
			textRect.size.height += textRectHeight;
			
			if (graphRect.size.width >= AVG_WIDE) {
				[leftText appendString:@"\nAverage:"];
			}
			else {
				[leftText appendString:@"\nAvg:"];
			}
			
			float usageSum = 0;
			for (i = 0; i < numCPUs; i++) {
				NSArray *cpuData = [CPUMiner dataForCPU:i];
				usageSum += [cpuData[0] average];
				usageSum += [cpuData[1] average];
				usageSum += [cpuData[2] average];
			}
			
			[rightText appendFormat:@"\n%3.1f%%", usageSum / (float)(numCPUs)];
		}
	}
		
    // draw the load average text
    if ([appSettings showLoadAverage]) {
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            [leftText appendString: @"\nLoad:"];
            if ([CPUMiner currentLoadAverage] == -1) {
                [rightText appendString:@"\nn/a"];
            }
            else {
                [rightText appendFormat:@"\n%4.2f", [CPUMiner currentLoadAverage]];
            }
        }
    }
	
    if ([appSettings cpuShowUptime]) {
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (graphRect.size.width >= UPTIME_WIDE) {
                [leftText appendString:@"\nUptime:"];
            }
            else {
                [leftText appendString:@"\nU:"];
            }
            
            if ([CPUMiner uptimeMinutes] < 10) 
                [rightText appendFormat:@"\n%ldd %ld:0%ld", (long)[CPUMiner uptimeDays], (long)[CPUMiner uptimeHours], (long)[CPUMiner uptimeMinutes]];
            else
                [rightText appendFormat:@"\n%ldd %ld:%ld", (long)[CPUMiner uptimeDays], (long)[CPUMiner uptimeHours], (long)[CPUMiner uptimeMinutes]];
        }
    }
    
    [leftText drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
	[rightText drawInRect:textRect withAttributes:[appSettings alignRightAttributes]];
    
    if (numCPUs == 2) {
        [centerText drawInRect:textRect withAttributes:[appSettings alignCenterAttributes]];
    }
    
    
    [gc setShouldAntialias:YES];
}

- (void)drawGraph:(NSRect)inRect {
    if ([self isHidden]) {
        return;
    }

    NSGraphicsContext *gc = [NSGraphicsContext currentContext]; 

    int i;
    float textRectHeight = [appSettings textRectHeight];

    NSRect textRect = NSMakeRect(3, inRect.size.height - textRectHeight, inRect.size.width - 6, textRectHeight);

    [gc setShouldAntialias:[appSettings antiAliasing]];

    [[appSettings graphBGColor] set];
    NSRectFill(inRect);
    
    NSInteger numCPUs = [CPUMiner numberOfCPUs];
	if (numCPUs == 0) return;
    
    if ([appSettings fastCPUUsage]) {
        // draw the divider line
        [[appSettings borderColor] set];
        NSRectFill(NSMakeRect(inRect.size.width - 7, 0, 2, inRect.size.height));

        // draw the fast cpu info
        [[appSettings graphFG2Color] set];
        NSInteger tmp = 0;
        NSInteger *fastValues = [CPUMiner fastValues];
        for (i = 0; i < numCPUs; i++) {
            tmp += fastValues[i];
        }
        
        NSRectFill(NSMakeRect(inRect.size.width - 7 + 2, 0, 5, ((float)tmp / (float)numCPUs) / 100. * graphSize.height));
	}

#ifdef XRG_DEBUG
	NSLog(@"In CPU DrawRect."); 
#endif
    
    // this is the rect that we will draw the graphs in
    if ([appSettings fastCPUUsage]) inRect.size.width -= 7;
    NSRect graphRect = NSMakeRect(0.0f, 0.0f, inRect.size.width, inRect.size.height);

    NSColor *colors[3];
    colors[0] = [appSettings graphFG1Color];
    colors[1] = [appSettings graphFG2Color];
    colors[2] = [appSettings graphFG3Color];

    graphRect.size.height /= (float)numCPUs;

    int cpu;

    BOOL colorful = [appSettings separateCPUColor];
    
    for (cpu = 0; cpu < numCPUs; ++cpu)
    {
        NSArray *cpuData = [CPUMiner dataForCPU:cpu];
        
        // Create a tmpDataSet of the same size as the other ones so we can do some manipulations.
        XRGDataSet *tmpDataSet = [[XRGDataSet alloc] initWithContentsOfOtherDataSet:cpuData[0]];
        [tmpDataSet addOtherDataSetValues:cpuData[1]];
        [tmpDataSet addOtherDataSetValues:cpuData[2]];
        
        if (colorful)
        {
            [self drawGraphWithDataFromDataSet:tmpDataSet maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[2]];
    
            [tmpDataSet subtractOtherDataSetValues:cpuData[2]];    
            [self drawGraphWithDataFromDataSet:tmpDataSet maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[1]];
    
            [self drawGraphWithDataFromDataSet:cpuData[0] maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[0]];
        }
        else {    
            [self drawGraphWithDataFromDataSet:tmpDataSet maxValue:100.0 inRect:graphRect flipped:NO filled:YES color:colors[0]];
        }
        
     
        graphRect.origin.y += graphRect.size.height;
    }
    [gc setShouldAntialias:YES];
    
    // draw the text
    [gc setShouldAntialias:[appSettings antialiasText]];

    if ([appSettings fastCPUUsage]) {
        textRect.size.width -= 7;
    }

    NSMutableString *leftText = [NSMutableString string];
    NSMutableString *rightText = [NSMutableString string];
    NSMutableString *centerText = [NSMutableString string];

    textRect.origin.y = inRect.size.height - textRectHeight;

    if (numCPUs == 1) {
        // Draw the first line with the label and current CPU usage
        [leftText setString:@"CPU"];
        NSArray *cpuData = [CPUMiner dataForCPU:0];
        [rightText appendFormat:@"%3.f%%", MAX(0, [(XRGDataSet *)cpuData[0] currentValue] + [(XRGDataSet *)cpuData[1] currentValue] + [(XRGDataSet *)cpuData[2] currentValue])];

        // draw the average usage text
        if ([appSettings cpuShowAverageUsage]) {
            if (textRect.origin.y - textRectHeight >= 0) {
                textRect.origin.y -= textRectHeight;
                textRect.size.height += textRectHeight;
                
                if (graphRect.size.width >= AVG_WIDE) {
                    [leftText appendString:@"\nAverage:"];
                }
                else {
                    [leftText appendString:@"\nAvg:"];
                }
                
                float usageSum = 0;
                NSArray *cpuData = [CPUMiner dataForCPU:0];
                usageSum += [cpuData[0] average];
                usageSum += [cpuData[1] average];
                usageSum += [cpuData[2] average];
        
                [rightText appendFormat:@"\n%3.1f%%", usageSum];
            }
        }
    }
    else if (numCPUs == 2) {
        // Draw the first line with the label and current CPU usage
        [centerText setString:@"CPU"];
        NSArray *cpuData = [CPUMiner dataForCPU:0];
        [leftText appendFormat:@"%3.f%%", MAX(0, [(XRGDataSet *)cpuData[0] currentValue] + [(XRGDataSet *)cpuData[1] currentValue] + [(XRGDataSet *)cpuData[2] currentValue])];
        
        cpuData = [CPUMiner dataForCPU:1];
        [rightText appendFormat:@"%3.f%%", MAX(0, [(XRGDataSet *)cpuData[0] currentValue] + [(XRGDataSet *)cpuData[1] currentValue] + [(XRGDataSet *)cpuData[2] currentValue])];

        // draw the average usage text
        if ([appSettings cpuShowAverageUsage]) {
            if (textRect.origin.y - textRectHeight >= 0) {
                textRect.origin.y -= textRectHeight;
                textRect.size.height += textRectHeight;
                
                if (graphRect.size.width >= AVG_WIDE) {
                    [centerText appendString:@"\nAverage"];
                }
                else {
                    [centerText appendString:@"\nAvg"];
                }
                
                float usageSum = 0;
                NSArray *cpuData = [CPUMiner dataForCPU:0];
                usageSum += [cpuData[0] average];
                usageSum += [cpuData[1] average];
                usageSum += [cpuData[2] average];
        
                [leftText appendFormat:@"\n%3.1f%%", usageSum];
                
                usageSum = 0;
                cpuData = [CPUMiner dataForCPU:1];
                usageSum += [cpuData[0] average];
                usageSum += [cpuData[1] average];
                usageSum += [cpuData[2] average];
        
                [rightText appendFormat:@"\n%3.1f%%", usageSum];
            }
        }
    }

    // draw the load average text
    if ([appSettings showLoadAverage]) {
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            [leftText appendString: @"\nLoad:"];
            if ([CPUMiner currentLoadAverage] == -1) {
                [rightText appendString:@"\nn/a"];
            }
            else {
                [rightText appendFormat:@"\n%4.2f", [CPUMiner currentLoadAverage]];
            }
        }
    }
            
    if ([appSettings cpuShowUptime]) {
        if (textRect.origin.y - textRectHeight >= 0) {
            textRect.origin.y -= textRectHeight;
            textRect.size.height += textRectHeight;
            
            if (graphRect.size.width >= UPTIME_WIDE) {
                [leftText appendString:@"\nUptime:"];
            }
            else {
                [leftText appendString:@"\nU:"];
            }
            
            if ([CPUMiner uptimeMinutes] < 10) 
                [rightText appendFormat:@"\n%ldd %ld:0%ld", (long)[CPUMiner uptimeDays], (long)[CPUMiner uptimeHours], (long)[CPUMiner uptimeMinutes]];
            else
                [rightText appendFormat:@"\n%ldd %ld:%ld", (long)[CPUMiner uptimeDays], (long)[CPUMiner uptimeHours], (long)[CPUMiner uptimeMinutes]];
        }
    }
    
    [leftText drawAtPoint:textRect.origin withAttributes:[appSettings alignLeftAttributes]];
    [rightText drawInRect:textRect withAttributes:[appSettings alignRightAttributes]];
    
    if (numCPUs == 2) {
        [centerText drawInRect:textRect withAttributes:[appSettings alignCenterAttributes]];
    }
        
    [gc setShouldAntialias:YES];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {       
    return YES;
}

- (void)mouseDown:(NSEvent *)theEvent {
    [parentWindow mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent {
    [parentWindow mouseDragged:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent {
    [parentWindow mouseUp:theEvent];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *myMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"CPU View"];
    NSMenuItem *tMI;

    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Top 10 CPU Processes" action:@selector(emptyEvent:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    // Need to get our process list.
	[processMiner graphUpdate:nil];
	NSArray *sortedProcesses = [processMiner processesSortedByCPUUsage];
	int i;
	for (i = 0; i < 10; i++) {
		NSDictionary *process = sortedProcesses[i];
		float cpu = [process[XRGProcessPercentCPU] floatValue];
		int pid = [process[XRGProcessID] intValue];
		NSString *command = process[XRGProcessCommand];
		
		tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSString stringWithFormat:@"%1.1f%% - %@ (id %d)", cpu, command, pid] action:@selector(emptyEvent:) keyEquivalent:@""];
		[myMenu addItem:tMI];
	}
	
    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open Activity Monitor..." action:@selector(openActivityMonitor:) keyEquivalent:@""];
    [myMenu addItem:tMI];

    [myMenu addItem:[NSMenuItem separatorItem]];
    
    tMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Open XRG CPU Preferences..." action:@selector(openCPUPreferences:) keyEquivalent:@""];
    [myMenu addItem:tMI];
    
    return myMenu;
}

- (void)emptyEvent:(NSEvent *)theEvent {
    /*
    printf("Got the event.\n");
    kinfo_proc **procList = calloc(1, sizeof(kinfo_proc **));
    size_t *procCount = calloc(1, sizeof(size_t));
    int retval = GetBSDProcessList(procList, procCount);
    if (retval == 0) {
        int i = 0;
        for (i = 0; i < *procCount; i++) {
            printf("%s %d %d\n", (*procList)[i].kp_proc.p_comm, (*procList)[i].kp_proc.p_pid, (*procList)[i].kp_proc.p_pctcpu);
        }
        printf("-------\n");
    }
    */
}

- (void)openCPUPreferences:(NSEvent *)theEvent {
    [[parentWindow controller] showPrefsWithPanel:@"CPU"];
}

- (void)openActivityMonitor:(NSEvent *)theEvent {
    [NSTask 
      launchedTaskWithLaunchPath:@"/usr/bin/open"
      arguments:@[@"/Applications/Utilities/Activity Monitor.app"]
    ];
}

- (BOOL) acceptsFirstMouse {
    return YES;
}

@end

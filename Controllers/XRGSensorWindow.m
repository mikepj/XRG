//
//  XRGSensorWindow.m
//  XRG
//
//  Created by Mike Piatek-Jimenez on 2/10/20.
//  Copyright © 2020 Gaucho Software. All rights reserved.
//

#import "XRGSensorWindow.h"
#import "XRGCPUMiner.h"

@interface XRGSensorWindow ()

@end

@implementation XRGSensorWindow

- (instancetype)init {
    if (self = [super initWithWindow:nil]) {
        [NSBundle.mainBundle loadNibNamed:@"Sensors" owner:self topLevelObjects:nil];
        
        self.miner = [[XRGTemperatureMiner alloc] init];
        self.miner.showUnknownSensors = YES;
        [self.miner setCurrentTemperatures];
        self.sensorKeys = [[self.miner allSensorKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [obj1 compare:obj2];
        }];
        
        __weak XRGSensorWindow *weakSelf = self;
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [weakSelf refresh];
        }];
        
        [self.tableView reloadData];
    }
    
    return self;
}

- (void)refresh {
    [self.miner setCurrentTemperatures];
    [self.tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.sensorKeys.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if ([identifier isEqualToString:@"sensorKey"]) {
        cell.textField.stringValue = self.sensorKeys[row];
    } else {
        cell.textField.stringValue = [NSString stringWithFormat:@"%.1f", [self.miner currentValueForKey:self.sensorKeys[row]]];
    }
    return cell;
}

- (IBAction)exportAction:(id)sender {
    // Copy text to a clipboard.
    NSMutableString *copyText = [[NSMutableString alloc] init];
    
    NSString *appVersion = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    if (!appVersion) appVersion = @"";
    
    [copyText appendFormat:@"XRG %@\n", appVersion];
    [copyText appendFormat:@"Mac model: %@\n", [XRGCPUMiner systemModelIdentifier]];
    [copyText appendFormat:@"Running macOS %@\n\n", [[NSProcessInfo processInfo] operatingSystemVersionString]];
    [copyText appendString:@"Discovered Sensors:\n"];
    
    for (NSString *sensorKey in self.sensorKeys) {
        [copyText appendFormat:@"\t%@:  %.1f\n", sensorKey, [self.miner currentValueForKey:sensorKey]];
    }
    
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:copyText forType:NSStringPboardType];
}

@end

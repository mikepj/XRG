//
//  XRGSensorViewController.m
//  XRG
//
//  Created by Mike Piatek-Jimenez on 11/8/20.
//  Copyright © 2020 Gaucho Software. All rights reserved.
//

#import "XRGSensorViewController.h"
#import "XRGTemperatureMiner.h"
#import "XRGCPUMiner.h"

@interface XRGSensorViewController ()

@property NSTimer *timer;

@property IBOutlet NSTextField *nameValuesLabel;
@property IBOutlet NSTextField *currentValuesLabel;
@property IBOutlet NSTextField *averageValuesLabel;
@property IBOutlet NSTextField *minValuesLabel;
@property IBOutlet NSTextField *maxValuesLabel;

@property (weak,nullable) IBOutlet NSButton *exportButton;

@end

@implementation XRGSensorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    __weak XRGSensorViewController *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf refresh];
    }];
}

- (void)refresh {
    NSArray<NSString *> *sensorKeys = [[XRGTemperatureMiner shared] locationKeysIncludingUnknown:YES];

    NSMutableString *sensorNames = [[NSMutableString alloc] init];
    NSMutableString *currentValues = [[NSMutableString alloc] init];
    NSMutableString *averageValues = [[NSMutableString alloc] init];
    NSMutableString *minValues = [[NSMutableString alloc] init];
    NSMutableString *maxValues = [[NSMutableString alloc] init];

    for (NSString *key in sensorKeys) {
        XRGSensorData *sensor = [[XRGTemperatureMiner shared] sensorForLocation:key];

        [sensorNames appendFormat:@"%@\n", sensor.humanReadableName];
        [currentValues appendFormat:@"%.0f\n", sensor.currentValue];
        [averageValues appendFormat:@"%.0f\n", sensor.dataSet.average];
        [minValues appendFormat:@"%.0f\n", sensor.dataSet.min];
        [maxValues appendFormat:@"%.0f\n", sensor.dataSet.max];
    }

    [self.nameValuesLabel setStringValue:sensorNames];
    [self.currentValuesLabel setStringValue:currentValues];
    [self.averageValuesLabel setStringValue:averageValues];
    [self.minValuesLabel setStringValue:minValues];
    [self.maxValuesLabel setStringValue:maxValues];
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

    for (NSString *sensorKey in [[XRGTemperatureMiner shared] locationKeysIncludingUnknown:YES]) {
        XRGSensorData *sensor = [[XRGTemperatureMiner shared] sensorForLocation:sensorKey];

        [copyText appendFormat:@"\t%@:  %.1f\n", sensor.label, sensor.currentValue];
    }

    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:copyText forType:NSStringPboardType];
}


@end

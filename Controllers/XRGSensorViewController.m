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
#import "XRGSettings.h"
#import "XRGAppDelegate.h"
#import "XRGStatsManager.h"

@interface XRGSensorViewController ()

@property NSTimer *timer;

@property IBOutlet NSTextField *nameValuesLabel;
@property IBOutlet NSTextField *currentValuesLabel;
@property IBOutlet NSTextField *statsValuesLabel;
@property IBOutlet NSLayoutConstraint *statsWidthConstraint;

@property (weak,nullable) IBOutlet NSButton *exportButton;

@property XRGSettings *appSettings;

@end

@implementation XRGSensorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    __weak XRGSensorViewController *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf refresh];
    }];

    id appDelegate = [NSApp delegate];
    if ([appDelegate isKindOfClass:[XRGAppDelegate class]]) {
        self.appSettings = [(XRGAppDelegate *)appDelegate appSettings];
    }

    self.statsWidthConstraint = [[self.statsValuesLabel widthAnchor] constraintEqualToConstant:20];
    [self.statsWidthConstraint setActive:YES];
}

- (void)refresh {
    NSArray<NSString *> *sensorKeys = [[XRGTemperatureMiner shared] locationKeysIncludingUnknown:YES];

    NSMutableString *sensorNames = [[NSMutableString alloc] init];
    NSMutableString *currentValues = [[NSMutableString alloc] init];
    NSMutableString *statsValues = [[NSMutableString alloc] init];

    BOOL convertToF = [self.appSettings tempUnits] == XRGTemperatureUnitsF;
    NSString *cUnitsString = [NSString stringWithFormat:@"%CC", (unsigned short)0x00B0];
    NSString *fUnitsString = [NSString stringWithFormat:@"%CF", (unsigned short)0x00B0];

    XRGStatsManager *statsManager = [XRGStatsManager shared];

    for (NSString *key in sensorKeys) {
        XRGSensorData *sensor = [[XRGTemperatureMiner shared] sensorForLocation:key];
        XRGStatsContentItem *sensorStats = [statsManager statForKey:key inModule:XRGStatsModuleNameTemperature];

        double current = sensorStats.last;
        double avg = sensorStats.average;
        double min = sensorStats.min;
        double max = sensorStats.max;

        NSString *units = sensor.units;
        if ([units isEqualToString:cUnitsString] && convertToF) {
            current = current * 1.8 + 32;
            avg = avg * 1.8 + 32;
            min = min * 1.8 + 32;
            max = max * 1.8 + 32;

            units = fUnitsString;
        }

        [sensorNames appendFormat:@"%@\n", sensor.humanReadableName];
        [currentValues appendFormat:@"%.0f%@\n", current, units];
        [statsValues appendFormat:@"%.0f - %.0f - %.0f\n", min, avg, max];
    }

    [self.nameValuesLabel setStringValue:sensorNames];
    [self.currentValuesLabel setStringValue:currentValues];
    [self.statsValuesLabel setStringValue:statsValues];

    [self.statsValuesLabel sizeToFit];
    self.statsWidthConstraint.constant = self.statsValuesLabel.frame.size.width;
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

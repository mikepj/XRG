//
//  XRGNonInteractableTextField.m
//  XRG
//
//  Created by Mike Piatek-Jimenez on 1/4/22.
//  Copyright © 2022 Gaucho Software. All rights reserved.
//

#import "XRGNonInteractableTextField.h"

@implementation XRGNonInteractableTextField

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

@end

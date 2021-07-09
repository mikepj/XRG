/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2016 Gaucho Software, LLC.
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
//  XRGDataSet.m
//  

#import "XRGDataSet.h"
#import <Accelerate/Accelerate.h>

#define USE_ACCELERATE CGFLOAT_IS_DOUBLE

@implementation XRGDataSet

- (instancetype) init {
	self = [super init];
	
	if (self) {
		_values = NULL;
		
		_min = 0;
		_max = 0;
		_sum = 0;
			
		_currentIndex = 0;
		_numValues = 0;
	}
    
    return self;
}

- (instancetype) initWithContentsOfOtherDataSet:(XRGDataSet *)otherDataSet {
    if (!otherDataSet) return nil;
    
	self = [self init];
	if (self) {
		_numValues = otherDataSet.numValues;
		if (_numValues == 0) return self;
		
		// Get a copy of the other values and set the current index
		CGFloat *otherValues = otherDataSet.values;
		_values = calloc(_numValues, sizeof(CGFloat));
		memcpy(_values, otherValues, _numValues * sizeof(CGFloat));
		self.currentIndex = otherDataSet.currentIndex;
		
		// Set the other class variables.
		_max = otherDataSet.max;
		_min = otherDataSet.min;
		_sum = otherDataSet.sum;
	}
    
    return self;
}

- (CGFloat) average {
    return self.sum / (CGFloat)self.numValues;
}

- (CGFloat) currentValue {
    if (_values == NULL) return 0;
    if (_currentIndex >= _numValues) return 0;
    
    return _values[_currentIndex];
}

// return an ordered list of values into the destinationArray given, assumed to be alloced already.
- (void) valuesInOrder:(CGFloat *)destinationArray {
    NSInteger index = (NSInteger)self.numValues - 1;
    
    for (NSInteger i = self.currentIndex; i >= 0; i--) {
        if (index < 0) break;
        
        destinationArray[index] = self.values[i];
        index--;
    }
    
    for (NSInteger i = self.numValues - 1; i > self.currentIndex; i--) {
        if (index < 0) break;
      
        destinationArray[index] = self.values[i];
        index--;
    }
}

- (void) reset {
    for (NSInteger i = 0; i < self.numValues; i++) {
        _values[i] = 0;
    }
}

- (void) resize:(size_t)newNumValues {
    if (newNumValues == 0) {
        self.min = 0;
        self.max = 0;
        self.sum = 0;
        
        free(self.values);
        self.values = NULL;
		self.numValues = newNumValues;
		return;
    }
    
    self.sum = 0;
    
    if (self.values) {
        CGFloat *tmpValues;
        NSInteger newValIndex = (NSInteger)newNumValues - 1;
        tmpValues = calloc(newNumValues, sizeof(CGFloat));
        
        for (NSInteger i = self.currentIndex; i >= 0; i--) {
            if (newValIndex < 0) break;
            
            tmpValues[newValIndex] = self.values[i];
            self.sum += tmpValues[newValIndex];
            newValIndex--;
        }
        
        for (NSInteger i = self.numValues - 1; i > self.currentIndex; i--) {
            if (newValIndex < 0) break;
          
            tmpValues[newValIndex] = self.values[i];
            self.sum += tmpValues[newValIndex];
            newValIndex--;
        }
                
        free(self.values);
        self.values = tmpValues;
        self.currentIndex = newNumValues - 1;
    }
    else {
        self.values = calloc(newNumValues, sizeof(CGFloat));
        self.currentIndex = 0;
    }
    self.numValues = newNumValues;
}

- (void) setNextValue:(CGFloat)nextVal {
    if (!self.numValues) return;

    self.currentIndex++;
    if (self.currentIndex == self.numValues) self.currentIndex = 0;
    
	CGFloat oldValue = self.values[self.currentIndex];
	
    self.sum -= self.values[self.currentIndex];
	self.values[self.currentIndex] = nextVal;
	self.sum += self.values[self.currentIndex];

    if (oldValue == self.min || oldValue == self.max) {
        [self updateExtrema];
    } else {
        if (self.values[self.currentIndex] < self.min) self.min = self.values[self.currentIndex];
        if (self.values[self.currentIndex] > self.max) self.max = self.values[self.currentIndex];
    }
}

- (void) setAllValues:(CGFloat)value {
	dispatch_apply(self.numValues, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
		self.values[i] = value;
	});
	
	self.min = value;
	self.max = value;
	self.sum = (CGFloat)self.numValues * value;
}

// Set the current values equal to the sum of the current plus the other data set values.
// currentIndex is assumed to be the same.
- (void) addOtherDataSetValues:(XRGDataSet *)otherDataSet {
    if (!otherDataSet || !otherDataSet.values) return;
    if (!self.values || self.numValues == 0) return;
    if (self.numValues != otherDataSet.numValues) return;
        
#if USE_ACCELERATE
    vDSP_Length valueLength = self.numValues;
    vDSP_vaddD(self.values, 1, otherDataSet.values, 1, self.values, 1, valueLength);
#else
    for (NSInteger i = 0; i < self.numValues; i++) {
        self.values[i] += otherDataSet.values[i];
    }
#endif

    [self updateExtrema];
}

// Set the current values equal to the difference of the current minus the other data set values.
// currentIndex is assumed to be the same.
- (void) subtractOtherDataSetValues:(XRGDataSet *)otherDataSet {
    if (!otherDataSet || !otherDataSet.values) return;
    if (!self.values || self.numValues == 0) return;
    if (self.numValues != otherDataSet.numValues) return;

#if USE_ACCELERATE
    vDSP_Length valueLength = self.numValues;
    vDSP_vsubD(otherDataSet.values, 1, self.values, 1, self.values, 1, valueLength);
#else
    for (NSInteger i = 0; i < self.numValues; i++) {
        self.values[i] -= otherDataSet.values[i];
    }
#endif

    [self updateExtrema];
}

- (void) divideAllValuesBy:(CGFloat)dividend {
	if (dividend == 0) return;
    if (!self.values || self.numValues == 0) return;

#if USE_ACCELERATE
    vDSP_Length valueLength = self.numValues;
    vDSP_vsdivD(self.values, 1, &dividend, self.values, 1, valueLength);
#else
	for (NSInteger i = 0; i < self.numValues; i++) {
		self.values[i] /= dividend;
	}
#endif

    self.max = self.max / dividend;
    self.min = self.min / dividend;
    self.sum = self.sum / dividend;
}

- (void) updateExtrema {
    if (!self.values || self.numValues == 0) return;

    double max = self.values[0];
    double min = self.values[0];
    double sum = 0;

#if USE_ACCELERATE
    vDSP_Length valueLength = self.numValues;

    vDSP_minvD(self.values, 1, &min, valueLength );
    vDSP_maxvD(self.values, 1, &max, valueLength );
    vDSP_sveD( self.values, 1, &sum, valueLength );
#else
    for (NSInteger i = 0; i < self.numValues; i++) {
        CGFloat value = self.values[i];
        if (value < min) min = value;
        if (value > max) max = value;
        sum += value;
    }
#endif

    self.min = min;
    self.max = max;
    self.sum = sum;
}

- (void) dealloc {
    if (_values) free(_values);
}


@end

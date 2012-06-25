/* 
 * XRG (X Resource Graph):  A system resource grapher for Mac OS X.
 * Copyright (C) 2002-2009 Gaucho Software, LLC.
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


@implementation XRGDataSet

- (id)init {
    values = nil;
    
    min = 0;
    max = 0;
    sum = 0;
        
    currentIndex = 0;
    numValues = 0;    
    
    return self;
}

- (id)initWithContentsOfOtherDataSet:(XRGDataSet *)otherDataSet {
    if (!otherDataSet) return nil;
    
    numValues = [otherDataSet numValues];
    if (numValues == 0) return [self init];
	if (numValues > 2000000) return [self init];
    
    // Get a copy of the other values and set the current index
    float *otherValues = [otherDataSet values];
    values = calloc(numValues, sizeof(float));
    memcpy(values, otherValues, numValues * sizeof(float));
    currentIndex = [otherDataSet currentIndex];
    
    // Set the other class variables.
    max          = [otherDataSet max];
    min          = [otherDataSet min];
    sum          = [otherDataSet sum];
    
    return self;
}

-(float) min {
    return min;
}

-(float) max {
    return max;
}

-(float) sum {
    return sum;
}

-(float) average {
    return sum / (float)numValues;
}

-(size_t) numValues {
    return numValues;
}

-(float) currentValue {
    return values[currentIndex];
}

// Return a pointer to the raw values array
-(float *) values {
    return values;
}

// Return the currentIndex
-(int) currentIndex {
    return currentIndex;
}

// return an ordered list of values into the destinationArray given, assumed to be alloced already.
-(void) valuesInOrder:(float *)destinationArray {
    NSInteger i;
    NSInteger index = (int)numValues - 1;
    
    for (i = currentIndex; i >= 0; i--) {
        if (index < 0) break;
        
        destinationArray[index] = values[i];
        index--;
    }
    
    for (i = numValues - 1; i > currentIndex; i--) {
        if (index < 0) break;
      
        destinationArray[index] = values[i];
        index--;
    }
}

-(void) resize:(size_t)newNumValues {
    NSInteger i;
    
    if (newNumValues == 0) {
        min = 0;
        max = 0;
        sum = 0;
        
        free(values);
        values = nil;
    }
    
    sum = 0;
    
    if (values) {    
        float *tmpValues;
        int newValIndex = (int)newNumValues - 1;
        tmpValues = calloc(newNumValues, sizeof(float));
        
        for (i = currentIndex; i >= 0; i--) {
            if (newValIndex < 0) break;
            
            tmpValues[newValIndex] = values[i];
            sum += tmpValues[newValIndex];
            newValIndex--;
        }
        
        for (i = numValues - 1; i > currentIndex; i--) {
            if (newValIndex < 0) break;
          
            tmpValues[newValIndex] = values[i];
            sum += tmpValues[newValIndex];
            newValIndex--;
        }
                
        free(values);     
        values = tmpValues;
        currentIndex = newNumValues - 1;
    }
    else {
        values = calloc(newNumValues, sizeof(float));
        currentIndex = 0;
    }
    numValues = newNumValues;
}

-(void) setNextValue:(float)nextVal {
    if (!numValues) return;

    currentIndex++;
    if (currentIndex == numValues) currentIndex = 0;
    
    sum -= values[currentIndex];
    
    if (values[currentIndex] == min || values[currentIndex] == max) {
        max = min = values[0];
        
        int i;
        for (i = 0; i < numValues; i++) {
            if (i == currentIndex) continue;
            if (values[i] < min) min = values[i];
            if (values[i] > max) max = values[i];
        }
    }
    
    values[currentIndex] = nextVal;
    
    if (values[currentIndex] < min) min = values[currentIndex];
    if (values[currentIndex] > max) max = values[currentIndex];
    
    sum += values[currentIndex];
}

- (void)setAllValues:(float)value {
	int i;
	for (i = 0; i < numValues; i++) {
		values[i] = value;
	}
	
	min = value;
	max = value;
	sum = (float)numValues * value;
}

// Set the current values equal to the sum of the current plus the other data set values.
// currentIndex is assumed to be the same.
-(void) addOtherDataSetValues:(XRGDataSet *)otherDataSet {
    if (!otherDataSet) return;
    if (numValues != [otherDataSet numValues]) return;
    
    float *otherValues = [otherDataSet values];
    
    if (otherValues) {
        max = min = values[0] + otherValues[0];
        sum = 0;
        
        int i;
        for (i = 0; i < numValues; i++) {
            values[i] += otherValues[i];
            
            if (max < values[i]) max = values[i];
            if (min > values[i]) min = values[i];
            sum += values[i];
        }
    }
}

// Set the current values equal to the difference of the current minus the other data set values.
// currentIndex is assumed to be the same.
-(void) subtractOtherDataSetValues:(XRGDataSet *)otherDataSet {
    if (!otherDataSet) return;
    if (numValues != [otherDataSet numValues]) return;
    
    float *otherValues = [otherDataSet values];
    
    if (otherValues) {
        max = min = values[0] - otherValues[0];
        sum = 0;

        int i;
        for (i = 0; i < numValues; i++) {
            values[i] -= otherValues[i];
            
            if (max < values[i]) max = values[i];
            if (min > values[i]) min = values[i];
            sum += values[i];
        }
    }
}

-(void) divideAllValuesBy:(float)dividend {
	if (dividend == 0) return;
	
	min = max = values[0] / dividend;
	
	int i;
	for (i = 0; i < numValues; i++) {
		values[i] /= dividend;
		
		if (max < values[i]) max = values[i];
		if (min > values[i]) min = values[i];
	}
}

- (void)dealloc {
    if (values) free(values);
    [super dealloc];
}


@end

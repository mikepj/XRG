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
//  XRGTemperatureMiner.m
//

#import "XRGTemperatureMiner.h"
#import "SMCSensors.h"
#import "definitions.h"

#import <mach/mach_host.h>
#import <mach/mach_port.h>
#import <mach/vm_map.h>

#undef DEBUG

@implementation XRGTemperatureMiner
- (instancetype)init {
	self = [super init];
	
	if (self) {
		host = mach_host_self();
		
		unsigned int count = HOST_BASIC_INFO_COUNT;
		host_basic_info_data_t info;
		host_info(host, HOST_BASIC_INFO, (host_info_t)&info, &count);
				
		
		// Set the number of CPUs
		numCPUs = [self setNumCPUs];
		
		// Initialize any variables that depend on the number of processors
		immediateCPUTemperatureC = malloc(numCPUs * sizeof(float));
		
		int i;
		for (i = 0; i < numCPUs; i++) {
			immediateCPUTemperatureC[i] = 0;
		}

		displayFans = YES;
		fanLocations        = [[NSMutableDictionary alloc] initWithCapacity:20];
		locationKeysInOrder = [[NSMutableArray alloc] initWithCapacity:20];	
		sensorData          = [[NSMutableDictionary alloc] initWithCapacity:20];
		smcSensors = [[SMCSensors alloc] init];
	}

    return self;
}

-(void)dealloc {
    free( immediateCPUTemperatureC );
    [fanLocations release];
    [locationKeysInOrder release];
    [sensorData release];
    [smcSensors release];
    [super dealloc];
}

- (int)setNumCPUs {
    processor_cpu_load_info_t		newCPUInfo;
    kern_return_t					kr;
    unsigned int					processor_count;
    mach_msg_type_number_t			load_count;

    kr = host_processor_info(host, 
                             PROCESSOR_CPU_LOAD_INFO, 
                             &processor_count, 
                             (processor_info_array_t *)&newCPUInfo, 
                             &load_count);
    if(kr != KERN_SUCCESS) {
        return 0;
    }
    else {
        vm_deallocate(mach_task_self(), 
                      (vm_address_t)newCPUInfo, 
                      (vm_size_t)(load_count * sizeof(*newCPUInfo)));
                      
        return (int)processor_count;
    }
}

- (int)numberOfCPUs {
    return numCPUs;
}

- (void)setCurrentTemperatures {
    bool haveValidTemperatures = NO;
    int i;
	
    // Only refresh the temperature every 5 seconds.
    temperatureCounter = (temperatureCounter + 1) % 5;
    if (temperatureCounter != 1) {
        return;
    }
    
	// Set each temperature sensor enable bit to NO.
	NSEnumerator *enumerator = [sensorData objectEnumerator];
	id value;
	while (value = [enumerator nextObject]) {
		value[GSEnable] = @"NO";
	}
    	
#if __ppc__    	
    // First try the host processor temperature method that works with older G3 and G4 machines.
	NS_DURING
		[self tryHostProcessorTemperature];
	NS_HANDLER
	NS_ENDHANDLER
    
    // Assume we have valid temperatures now
    haveValidTemperatures = YES;
    
    for (i = 0; i < numCPUs; i++) {
        if (immediateCPUTemperatureC[i] == 0) {
            // This method didn't work, go to the next one.
            haveValidTemperatures = NO;
            break;
        }
    }
    
    if (haveValidTemperatures) {
		// Before returning, go through the values and find the ones that aren't enabled.
		enumerator = [sensorData objectEnumerator];
		while (value = [enumerator nextObject]) {
			if ([[value objectForKey:GSEnable] boolValue] == NO) {
				[[value objectForKey:GSDataSetKey] setNextValue:0];
				[value setObject:[NSNumber numberWithInt:0] forKey:GSCurrentValueKey];
			}
		}
		
		return;
	}
    
    // Second, try the IOHWSensor method that works with the G5s, the AlBook G4s, and iBook G4s.
	NS_DURING
		[self tryIOHWSensorTemperature];
	NS_HANDLER
	NS_ENDHANDLER
    	
    // Assume we have valid temperatures now
    haveValidTemperatures = YES;
    
    for (i = 0; i < numCPUs; i++) {
        if (immediateCPUTemperatureC[i] == 0) {
            // This method didn't work, go to the next one.
            haveValidTemperatures = NO;
            break;
        }
    }
    
    if (haveValidTemperatures) {
		// Before returning, go through the values and find the ones that aren't enabled.
		enumerator = [sensorData objectEnumerator];
		while (value = [enumerator nextObject]) {
			if ([[value objectForKey:GSEnable] boolValue] == NO) {
				[[value objectForKey:GSDataSetKey] setNextValue:0];
				[value setObject:[NSNumber numberWithInt:0] forKey:GSCurrentValueKey];
			}
		}
		
		return;
	}
	
    // Finally, try the AppleCPUThermo method that works with MDD G4s and XServe
	@try {
		[self tryCPUThermoTemperature];
	} @catch (NSException *e) {}
	
#else
	
	// Intel: only SMC for now 
	if(haveValidTemperatures)
		i = 0; // make the compiler happy 
	@try {
		[self trySMCTemperature];
	} @catch (NSException *e) {}

#endif
		
	// Before returning, go through the values and find the ones that aren't enabled.
	enumerator = [sensorData objectEnumerator];
	while (value = [enumerator nextObject]) {
		if ([value[GSEnable] boolValue] == NO) {
			[value[GSDataSetKey] setNextValue:0];
			value[GSCurrentValueKey] = @0;
		}
	}
}

// Adapted code from Aquamon
- (void)tryHostProcessorTemperature {
    kern_return_t kr = 0;
    unsigned int processor_count = 0, temps_count = 0;
    processor_info_array_t temps = 0;
    int	i;

    kr = host_processor_info(host, PROCESSOR_TEMPERATURE, &processor_count, &temps, &temps_count);
    if (kr != KERN_SUCCESS) {
        for (i = 0; i < numCPUs; i++) 
            immediateCPUTemperatureC[i] = 0;

		/* 
		// Not sure why I added this, but I don't think it should be here.
		if (temps != 0) {
			vm_deallocate(mach_task_self(), (vm_address_t)temps, temps_count);
		}
		 */
		
        return;
    }
    else {
        if (temps[0] < 0) {
            for (i = 0; i < numCPUs; i++) 
                immediateCPUTemperatureC[i] = 0;
                
			if (temps != 0) {
				// temps should always be alloced here, but just in case.
				vm_deallocate(mach_task_self(), (vm_address_t)temps, temps_count);
			}
            return;
        }
        else {
            for (i = 0; i < temps_count; i++) {
                int difference = temps[i] - immediateCPUTemperatureC[i];
                
                if (immediateCPUTemperatureC[i] == 0) {
                    immediateCPUTemperatureC[i] = temps[i];                
                }
                else if (difference > 5 || difference < -5) {
                    immediateCPUTemperatureC[i] += difference / 5;
                }
                else {
                    immediateCPUTemperatureC[i] = temps[i];
                }
            }
        }
		
		if (temps != 0) {
			// temps should always be alloced here, but just in case.
			vm_deallocate(mach_task_self(), (vm_address_t)temps, temps_count);
		}
    }
}

/*
 * Documentation on methods of accessing temperature values from the IOKit.
 *
 * Aluminum 12" Powerbook (867Mhz)
 *   Location Keys:
 *     CPU BOTTOMSIDE
 *     GPU TOPSIDE
 *
 * Aluminum 12" Powerbook (1Ghz)
 *   Service Name to Match: "IOHWSensor"
 *   Dictionary key with temperature value:  "current-value"
 *   Location Keys:
 *     HDD BOTTOMSIDE
 *     CPU TOPSIDE
 *     GPU ON DIE
 *     CPU CORE
 *     REAR MAIN ENCLOSURE
 *     BATTERY
 *   Divide temperature value by 65536 to get temperature in °C
 * 
 * Aluminum 15" and 17" Powerbooks
 *   Service Name to Match: "IOHWSensor"
 *   Dictionary key with temperature value:  "current-value"
 *   Location Keys:
 *     CPU/INTREPID BOTTOMSIDE
 *     CPU BOTTOMSIDE
 *     PWR SUPPLY BOTTOMSIDE
 *     CPU CORE
 *     REAR LEFT EXHAUST
 *     REAR RIGHT EXHAUST
 *     BATTERY
 *   Divide temperature value by 65536 to get temperature in °C
 * 
 * G4 iBooks
 *   Service Name to Match: "IOHWSensor"
 *   Dictionary key with temperature value:  "current-value"
 *   Location Keys:
 *     PWR/MEMORY BOTTOMSIDE
 *     CPU BOTTOMSIDE
 *     GPU ON DIE
 *     CPU CORE
 *     REAR MAIN ENCLOSURE
 *     BATTERY
 *   Divide temperature value by 65536 to get temperature in °C
 * 
 * PowerMac G5
 *   Service Name to Match: "IOHWSensor"
 *   Dictionary key with temperature value:  "current-value"
 *   Location Keys:
 *     DRIVE BAY        (Back of the corridor with the Hard Disks and Super Drive)
 *     BACKSIDE         (Back of the Main Logic Board?)
 *     U3 HEATSINK      (Temperature of the heatsink on the U3 Memory and I/O Controller)
 *     MLB MAX6690 AMB  (Ambient temperature at the location of the MAX6690 IC on the Main Logic Board)
 *     MLB INLET AMB    (Ambient temperature on air intake for the Main Logic Board)
 *     SLOT 12V         (PCI Slots)
 *     SLOT 5V          (PCI Slots)
 *     SLOT 3.3V        (PCI Slots)
 *     SLOT COMBINED    (PCI Slots)
 *     CPU A AD7417 AMB (Ambient temperature at the location of the AD7417 IC for this processor)
 *     CPU A AD7417 AD1 (CPU A diode temperature)
 *     CPU A AD7417 AD2 (CPU A 12V Current)
 *     CPU A AD7417 AD3 (CPU A Voltage)
 *     CPU A AD7417 AD4 (CPU A Current)
 *     CPU B AD7417 AMB (Ambient temperature at the location of the AD7417 IC for this processor)
 *     CPU B AD7417 AD1 (CPU B diode temperature)
 *     CPU B AD7417 AD2 (CPU B 12V Current)
 *     CPU B AD7417 AD3 (CPU B Voltage)
 *     CPU B AD7417 AD4 (CPU B Current)
 *   Divide temperature value by 65536 to get temperature in °C
 *   Notes:  AD7417 AD* values are not all temperatures like the other keys.  
 *           CPU B keys aren't present on single processor systems.
 *           AD7417 AD* values are not scaled as the other ones are.  Dividing by 65536 gives 0 < n < 1.
 *
 * PowerMac G4 / XServe
 *   Service Name to Match: "AppleCPUThermo"
 *   Dictionary key with temperature value: "temperature"
 *   Location Keys:  None...should only have the key "temperature" with the temperature value.
 *   Divide temperature value by 256 to get temperature in °C
 *
 */
 
- (void)tryIOHWSensorTemperature {
    kern_return_t    returnValue;
    io_iterator_t    iterator;
    
    // Check that we have some CPUs
    if (numCPUs == 0) return;
    
    // Get all the services that match "IOHWSensor"
    returnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("IOHWSensor"), &iterator);
    if (returnValue != kIOReturnSuccess) return;
    
    // Now loop through all the matching services to find any that will give us the temperatures or fan speeds.
    io_object_t serviceObject;
    while ((serviceObject = IOIteratorNext(iterator))) {
        // Put this services object into a CF Dictionary object.
		NSMutableDictionary *serviceDictionary;
        returnValue = IORegistryEntryCreateCFProperties(serviceObject, 
														(CFMutableDictionaryRef *)&serviceDictionary, 
														kCFAllocatorDefault, 
														kNilOptions);
        if (returnValue != kIOReturnSuccess) {
            IOObjectRelease(serviceObject);
            continue;
        }
		

		// Check that this location monitors temperature.
		id sensorType = serviceDictionary[@"type"];
		if ([sensorType isKindOfClass:[NSString class]]) {
			// Get the value of the location key in the service dictionary.
			id location = serviceDictionary[@"location"];
			
			// Now check that our location key is not null and has a string value.
			if ([location isKindOfClass:[NSString class]]) {
			
				if ([sensorType isEqualToString:@"temperature"]) {
					// This is a temperature sensor.
					id currentValue = serviceDictionary[@"current-value"];
					if ([currentValue isKindOfClass:[NSNumber class]]) {
						int tempInt;
						if ((tempInt = [currentValue intValue])) {
							if (tempInt / 65536 > 1 && tempInt / 65536 < 300) {
								[self setCurrentValue:(float)tempInt / 65536. 
											 andUnits:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0]
										  forLocation:location];
							}
						}
					}
				}
				else if ([sensorType isEqualToString:@"temp"]) {
					// This is a temperature sensor (different type found in the iMac G5 for one.
					id currentValue = serviceDictionary[@"current-value"];
					if ([currentValue isKindOfClass:[NSNumber class]]) {
						int tempInt;
						if ((tempInt = [currentValue intValue])) {
							if (tempInt / 10. > 1 && tempInt / 10. < 300) {
								[self setCurrentValue:(float)tempInt / 10. 
											 andUnits:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0] 
										  forLocation:location];
							}
							else if (tempInt / 65536.f > 1 && tempInt / 65536.f < 300) {
								[self setCurrentValue:(float)tempInt / 65536.f
											 andUnits:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0] 
										  forLocation:location];
							}
						}
					}
				}
				else if ([sensorType isEqualToString:@"adc"]) {
					// This is an ADC sensor.  The only known value we can get from here is CPU [AB] AD7417 AD1 on the G5s (old method, less accurate)
					id currentValue = serviceDictionary[@"current-value"];
					if ([currentValue isKindOfClass:[NSNumber class]]) {
						int tempInt;
						if ((tempInt = [currentValue intValue])) {
							if (tempInt / 10 > 1 && tempInt / 10 < 300 && [(NSString *)location hasSuffix:@"AD1"]) {
								if ([(NSString *)location hasPrefix:@"CPU A"]) {
									location = @"CPU A Diode Temp";
								}
								else if ([(NSString *)location hasPrefix:@"CPU B"]) {
									location = @"CPU B Diode Temp";
								}
								
								[self setCurrentValue:(float)tempInt / 10. 
											 andUnits:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0] 
										  forLocation:location];
							}							
						}
					}
				}
				else if ([sensorType isEqualToString:@"fanspeed"]) {
					// This is an fan speed sensor found on the exhaust fans of Powerbooks.  
					id currentValue = serviceDictionary[@"current-value"];
					if ([currentValue isKindOfClass:[NSNumber class]]) {
						int tempInt;
						if ((tempInt = [currentValue intValue])) {
							[self setCurrentValue:(float)tempInt / 65536. 
										 andUnits:@" rpm"
									  forLocation:location];
						}
					}
				}
			}
		}		
        
        // Clean up
        CFRelease(serviceDictionary);
        IOObjectRelease(serviceObject);
    }
    IOObjectRelease(iterator);

	// Get all the services that match "IOHWControl" for exhaust fans in Powerbooks.
    returnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("IOHWControl"), &iterator);
    if (returnValue != kIOReturnSuccess) {
        return;
    }
    
    // Now loop through all the matching services to find any that will give us the fan speeds.
    while ((serviceObject = IOIteratorNext(iterator))) {
        // Put this services object into a CF Dictionary object.
		NSMutableDictionary *serviceDictionary;
        returnValue = IORegistryEntryCreateCFProperties(serviceObject, 
														(CFMutableDictionaryRef *)&serviceDictionary, 
														kCFAllocatorDefault, 
														kNilOptions);
        if (returnValue != kIOReturnSuccess) {
            IOObjectRelease(serviceObject);
            continue;
        }
		
		
		// Check that this location monitors temperature.
		id sensorType = serviceDictionary[@"type"];
		if ([sensorType isKindOfClass:[NSString class]]) {
			// Get the value of the location key in the service dictionary.
			id location = serviceDictionary[@"location"];
			
			// Now check that our location key is not null and has a string value.
			if ([location isKindOfClass:[NSString class]]) {
				
				if ([sensorType isEqualToString:@"fan-rpm"]) {
					id currentValue = serviceDictionary[@"target-value"];
					if ([currentValue isKindOfClass:[NSNumber class]]) {
						int tempInt;
						if ((tempInt = [currentValue intValue])) {
							[self setCurrentValue:(float)tempInt 
										 andUnits:@" rpm"
									  forLocation:location];
						}
					}
				}
			}
		}		
        
        // Clean up
        CFRelease(serviceDictionary);
        IOObjectRelease(serviceObject);
    }
	IOObjectRelease(iterator);
	
	if (displayFans) {
		// Get all the services that match "AppleFCU" (present in PowerMac G5s)
		returnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("AppleFCU"), &iterator);
		if (returnValue != kIOReturnSuccess) {
			return;
		}
		
		// Now loop through all the matching services to find any that will give us the temperatures or fan speeds.
		while ((serviceObject = IOIteratorNext(iterator))) {
			// Put this services object into a CF Dictionary object.
			NSMutableDictionary *serviceDictionary;
			returnValue = IORegistryEntryCreateCFProperties(serviceObject, (CFMutableDictionaryRef *)&serviceDictionary, kCFAllocatorDefault, kNilOptions);
			if (returnValue != kIOReturnSuccess) {
				IOObjectRelease(serviceObject);
				continue;
			}
			
			NSMutableArray *controlInfoArray = serviceDictionary[@"control-info"];
			NSInteger numItems = [controlInfoArray count];
			NSInteger i;
			for (i = 0; i < numItems; i++) {
				NSString *value = controlInfoArray[i][@"target-value"];
				if ([value intValue] == 0) {
					continue;
				}
				
				NSMutableString *loc = [NSMutableString stringWithString:(NSString *)controlInfoArray[i][@"location"]];
				if (![loc hasSuffix:@"PUMP"]) {
					[loc appendString:@" Fan"];
				}
				
				[self setCurrentValue:[value floatValue] 
							 andUnits:@" rpm" 
						  forLocation:loc];
				fanLocations[loc] = @"";
			}
					
			// Clean up
			CFRelease(serviceDictionary);
			IOObjectRelease(serviceObject);
		}
		IOObjectRelease(iterator);
		
		// Get all the services that match "PowerMac7_2_PlatformPlugin" (present in PowerMac G5s)
		returnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("PowerMac7_2_PlatformPlugin"), &iterator);
		if (returnValue != kIOReturnSuccess) {
			return;
		}
		
		// Now loop through all the matching services to find any that will give us the temperatures or fan speeds.
		while ((serviceObject = IOIteratorNext(iterator))) {
			// Put this services object into a CF Dictionary object.
			NSMutableDictionary *serviceDictionary;
			returnValue = IORegistryEntryCreateCFProperties(serviceObject, 
															(CFMutableDictionaryRef *)&serviceDictionary, 
															kCFAllocatorDefault, 
															kNilOptions);
			if (returnValue != kIOReturnSuccess) {
				IOObjectRelease(serviceObject);
				continue;
			}
			
			NSArray *IOHWControls = serviceDictionary[@"IOHWControls"];
			int i;
			for (i = 0; i < [IOHWControls count]; i++) {
				// Check that this location monitors temperature.
				id sensorType = IOHWControls[i][@"type"];
				if ([sensorType isKindOfClass:[NSString class]]) {
					// Get the value of the location key in the service dictionary.
					id location = IOHWControls[i][@"location"];
					
					// Now check that our location key is not null and has a string value.
					if ([location isKindOfClass:[NSString class]]) {
						
						if ([sensorType isEqualToString:@"fan-pwm"]) {
							// This is an fan speed sensor found on the exhaust fans of Powerbooks.  
							id currentValue = IOHWControls[i][@"target-value"];
							if ([currentValue isKindOfClass:[NSNumber class]]) {
								int tempInt;
								if ((tempInt = [currentValue intValue])) {
									[self setCurrentValue:(float)tempInt 
												 andUnits:@"%"
											  forLocation:location];
									fanLocations[location] = @"";
								}
							}
						}
					}
				} 
			}	
			
			IOHWControls = serviceDictionary[@"IOHWSensors"];
			for (i = 0; i < [IOHWControls count]; i++) {
				// This is an ADC sensor.  The only known value we can get from here is CPU [AB] AD7417 AD1 on the G5s (new method, more accurate, will replace values found earlier)
				// Check that this location monitors temperature.
				id sensorType = IOHWControls[i][@"type"];
				if ([sensorType isKindOfClass:[NSString class]]) {
					// Get the value of the location key in the service dictionary.
					id location = IOHWControls[i][@"location"];
					
					// Now check that our location key is not null and has a string value.
					if ([location isKindOfClass:[NSString class]]) {
						
						if ([sensorType isEqualToString:@"temperature"]) {
							// This is an fan speed sensor found on the exhaust fans of Powerbooks.  
							id currentValue = IOHWControls[i][@"current-value"];
							if ([currentValue isKindOfClass:[NSNumber class]]) {
								float tempFloat;
								if ((tempFloat = [currentValue floatValue] / 65536.f) && [(NSString *)location hasSuffix:@"AD1"]) {
									if ([(NSString *)location hasPrefix:@"CPU A"]) {
										location = @"CPU A Diode Temp";
									}
									else if ([(NSString *)location hasPrefix:@"CPU B"]) {
										location = @"CPU B Diode Temp";
									}
										
									[self setCurrentValue:tempFloat 
												 andUnits:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0] 
											  forLocation:location];
								}
							}
						}
					}
				} 
			}	
						
			// Clean up
			CFRelease(serviceDictionary);
			IOObjectRelease(serviceObject);
		}
		IOObjectRelease(iterator);	
		
		// Get all the services that match "SMU_Neo2_PlatformPlugin" (present in iMac G5s)
		returnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("SMU_Neo2_PlatformPlugin"), &iterator);
		if (returnValue != kIOReturnSuccess) {
			return;
		}
		
		// Now loop through all the matching services to find any that will give us the temperatures or fan speeds.
		while ((serviceObject = IOIteratorNext(iterator))) {
			// Put this services object into a CF Dictionary object.
			NSMutableDictionary *serviceDictionary;
			returnValue = IORegistryEntryCreateCFProperties(serviceObject, 
															(CFMutableDictionaryRef *)&serviceDictionary, 
															kCFAllocatorDefault, 
															kNilOptions);
			if (returnValue != kIOReturnSuccess) {
				IOObjectRelease(serviceObject);
				continue;
			}
			
			NSArray *IOHWControls = serviceDictionary[@"IOHWControls"];
			int i;
			for (i = 0; i < [IOHWControls count]; i++) {
				// Check that this location monitors temperature.
				id sensorType = IOHWControls[i][@"type"];
				if ([sensorType isKindOfClass:[NSString class]]) {
					// Get the value of the location key in the service dictionary.
					id location = IOHWControls[i][@"location"];
					
					// Now check that our location key is not null and has a string value.
					if ([location isKindOfClass:[NSString class]]) {
						
						if ([sensorType isEqualToString:@"fan-rpm"]) {
							// This is an fan speed sensor found on the exhaust fans of Powerbooks.  
							id currentValue = IOHWControls[i][@"target-value"];
							if ([currentValue isKindOfClass:[NSNumber class]]) {
								int tempInt;
								if ((tempInt = [currentValue intValue])) {
									[self setCurrentValue:(float)tempInt 
												 andUnits:@" rpm"
											  forLocation:location];
									fanLocations[location] = @"";
								}
							}
						}
					}
				} 
			}		
			
			// Clean up
			CFRelease(serviceDictionary);
			IOObjectRelease(serviceObject);
		}
		IOObjectRelease(iterator);		
	}
        	
    // Now check our NSDictionary for keys that give CPU temperature
    id tmpDictionary;
    tmpDictionary = sensorData[@"CPU TOPSIDE"];
    if (tmpDictionary != nil) {
        // This is a 12" Aluminum Powerbook
        immediateCPUTemperatureC[0] = [tmpDictionary[GSCurrentValueKey] floatValue];
    }
    
    tmpDictionary = sensorData[@"CPU BOTTOMSIDE"];
    if (tmpDictionary != nil) {
        // This is a 15" or 17" Aluminum Powerbook, or a G4 iBook
        immediateCPUTemperatureC[0] = [tmpDictionary[GSCurrentValueKey] floatValue];
    }
    
    tmpDictionary = sensorData[@"CPU CORE"];
    if (tmpDictionary != nil) {
        // This should be on G4 Powerbooks and iBooks
        immediateCPUTemperatureC[0] = [tmpDictionary[GSCurrentValueKey] floatValue];
    }

    tmpDictionary = sensorData[@"CPU A AD7417 AMB"];
    if (tmpDictionary != nil) {
        // CPU 1 on a PowerMac G5
        immediateCPUTemperatureC[0] = [tmpDictionary[GSCurrentValueKey] floatValue];
    }

    tmpDictionary = sensorData[@"CPU B AD7417 AMB"];
    if (tmpDictionary != nil) {
        // CPU 2 on a PowerMac G5
        if (numCPUs > 1) {
            immediateCPUTemperatureC[1] = [tmpDictionary[GSCurrentValueKey] floatValue];
        }
    }

    tmpDictionary = sensorData[@"CPU A Diode Temp"];
    if (tmpDictionary != nil) {
        // CPU 1 on a PowerMac G5 if it's available.
        immediateCPUTemperatureC[0] = [tmpDictionary[GSCurrentValueKey] floatValue];
    }
	
    tmpDictionary = sensorData[@"CPU B Diode Temp"];
    if (tmpDictionary != nil) {
        // CPU 2 on a PowerMac G5 if it's available.
        if (numCPUs > 1) {
            immediateCPUTemperatureC[1] = [tmpDictionary[GSCurrentValueKey] floatValue];
        }
    }
}

- (void)tryCPUThermoTemperature {
    kern_return_t    returnValue;
    io_iterator_t    iterator;
    //char             locationBuffer[64];
    
    // Check that we have some CPUs
    if (numCPUs == 0) return;
    
    // Get all the services that match "AppleCPUThermo"
    returnValue = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("AppleCPUThermo"), &iterator);
    if (returnValue != kIOReturnSuccess) {
        return;
    }
    
    // Now loop through all the matching services to find any that will give us the temperatures.
    io_object_t serviceObject;
    int index = 0;
    while ((serviceObject = IOIteratorNext(iterator))) {
        // Put this services object into a CF Dictionary object.
        CFMutableDictionaryRef serviceDictionary;
        returnValue = IORegistryEntryCreateCFProperties(serviceObject, &serviceDictionary, kCFAllocatorDefault, kNilOptions);
        if (returnValue != kIOReturnSuccess) {
            IOObjectRelease(serviceObject);
            continue;
        }
        
        // Read the temperature value into our NSDictionary
        CFNumberRef cfTemperature;
        if (CFDictionaryGetValueIfPresent(serviceDictionary, CFSTR("temperature"), (const void **) &cfTemperature)) {
            if (CFGetTypeID(cfTemperature) == CFNumberGetTypeID()) {
                int tempInt;
                if (CFNumberGetValue(cfTemperature, kCFNumberIntType, &tempInt)) {   
                    if (index <= numCPUs) {
                        immediateCPUTemperatureC[index++] = (float)tempInt / 256.;
                    }
                }
            }
        }
        
        // Clean up
        CFRelease(serviceDictionary);
        IOObjectRelease(serviceObject);
    }
    

    IOObjectRelease(iterator);
}

- (void) trySMCTemperature {
	id key;
	int i;
	// [smcReader reset];
    BOOL showUnknownSensors = [[NSUserDefaults standardUserDefaults] boolForKey:XRG_tempShowUnknownSensors];
	NSDictionary *values = [smcSensors temperatureValuesExtended:showUnknownSensors];
	//NSLog(@"values: %@", values);
	NSEnumerator *keyEnum = [values keyEnumerator];
	
	while( nil != (key = [keyEnum nextObject]) )
	{
		id aValue = values[key];
		if (![aValue isKindOfClass:[NSNumber class]]) continue;		// Fix TE..
        
		float temperature = [aValue floatValue];
        NSString *humanReadableName = [smcSensors humanReadableNameForKey:key];

		[self setCurrentValue:temperature
					 andUnits:[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0] 
				  forLocation:humanReadableName];
		
		/* strategy OK for CoreDuos: set both cores temperatures to the current CPU temp */ 
		NSRange r = [key rangeOfString:@"CPU"];
		if (r.location != NSNotFound) {
			int i;
			for( i = 0; i < numCPUs; ++i )
				immediateCPUTemperatureC[i] = temperature; 
		}
		
	}
    
	if( displayFans ) {
        values = [smcSensors fanValues];
        NSArray *keys = [values allKeys];
        for (i = 0; i < [keys count]; i++) {
            id fanKey = keys[i];
            NSString *fanLocation = fanKey;
            
            id fanDict = values[fanKey];
			
			// Find the actual fan speed key.
			NSArray *fanDictKeys = [fanDict allKeys];
			NSUInteger speedKeyIndex = [fanDictKeys indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop){
				if ([obj hasSuffix:@"Ac"]) {
					*stop = YES;
					return YES;
				}
				
				return NO;
			}];
			if (speedKeyIndex != NSNotFound) {
				id fanSpeedKey = fanDictKeys[speedKeyIndex];
				[self setCurrentValue:[fanDict[fanSpeedKey] floatValue]
							 andUnits:@" rpm"
						  forLocation:fanLocation];
			}
        }
    }
	
	return;
}

- (void)setDisplayFans:(bool)yesNo {
	displayFans = yesNo;
	
	if (displayFans == NO) {
		NSArray *fanLocationKeys = [fanLocations allKeys];
		
		int i;
		for (i = 0; i < [fanLocationKeys count]; i++) {
			NSString *location = fanLocationKeys[i];
			
			[sensorData removeObjectForKey:location];			
		}

		[self regenerateLocationKeyOrder];
	}
}

- (float *)currentCPUTemperature {
    [self setCurrentTemperatures];
    return immediateCPUTemperatureC;
}

- (NSArray *)locationKeys {
    return [sensorData allKeys];
}

- (NSArray *)locationKeysInOrder {
    return locationKeysInOrder;
}

- (NSString *)unitsForLocation:(NSString *)location {
	return sensorData[location][GSUnitsKey];
}

- (void)regenerateLocationKeyOrder {
    NSArray        *locations        = [sensorData allKeys];
    NSInteger      numLocations      = [locations count];
    bool           *alreadyUsed      = calloc(numLocations, sizeof(bool));
    int i;

	[locationKeysInOrder removeAllObjects];

    for (i = 0; i < numLocations; i++) {
        if (locations[i] == nil) {
            alreadyUsed[i] = YES;
        }
    }
    
	NSMutableArray *types = [NSMutableArray arrayWithObjects:
		[NSString stringWithFormat:@"%CC", (unsigned short)0x00B0], 
		@" rpm", 
		@"%", 
		nil];

	int typeIndex;
	for (typeIndex = 0; typeIndex < [types count]; typeIndex++) {
		NSMutableArray *tmpCPUCore = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpCPUA    = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpCPUB    = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpCPU     = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpU3      = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpGPU     = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpBattery = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpDrive   = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *tmpOthers  = [NSMutableArray arrayWithCapacity:3];
		
		for (i = 0; i < numLocations; i++) {
			if (alreadyUsed[i]) continue;
			
			NSString *location = locations[i];
			if (![sensorData[location][GSUnitsKey] isEqualToString:types[typeIndex]]) {
				continue;
			}

			// Matches CPU and CORE
			NSRange r = [location rangeOfString:@"CPU"];
			if (r.location != NSNotFound) {
				r = [location rangeOfString:@"CORE"];
				if (r.location != NSNotFound) {
					[tmpCPUCore addObject:location];
					alreadyUsed[i] = YES;
					continue;
				}
			}
			
			// Matches CPU A
			r = [location rangeOfString:@"CPU A"];
			if (r.location != NSNotFound) {
				[tmpCPUA addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
		
			// Matches CPU B
			r = [location rangeOfString:@"CPU B"];
			if (r.location != NSNotFound) {
				[tmpCPUB addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
		
			// Matches CPU
			r = [location rangeOfString:@"CPU"];
			if (r.location != NSNotFound) {
				[tmpCPU addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
					
			// Matches U3 (for the memory controller in a G5)
			r = [location rangeOfString:@"U3"];
			if (r.location != NSNotFound) {
				[tmpU3 addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
			
			// Matches Memory (for Intel SMC)
			r = [location rangeOfString:@"Memory"];
			if (r.location != NSNotFound) {
				[tmpU3 addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}			
		
			// Matches GPU
			r = [location rangeOfString:@"GPU"];
			if (r.location != NSNotFound) {
				[tmpGPU addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
		
			// Add any that match Battery
			r = [location rangeOfString:@"BATTERY"];
			if (r.location != NSNotFound) {
				[tmpBattery addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
		
			// Add any that match Drive
			r = [location rangeOfString:@"DRIVE"];
			if (r.location != NSNotFound) {
				[tmpDrive addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
			
			r = [location rangeOfString:@"HDD"];
			if (r.location != NSNotFound) {
				[tmpDrive addObject:location];
				alreadyUsed[i] = YES;
				continue;
			}
		}
		
		// Loop through and add any left overs
		for (i = 0; i < numLocations; i++) {
			if (!alreadyUsed[i] & [sensorData[locations[i]][GSUnitsKey] isEqualToString:types[typeIndex]]) {
				[tmpOthers addObject:locations[i]];
				alreadyUsed[i] = YES;
			}
		}
		
		[locationKeysInOrder addObjectsFromArray:[tmpCPUCore sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpCPUA sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpCPUB sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpCPU sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpGPU sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpU3 sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpBattery sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpDrive sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
		[locationKeysInOrder addObjectsFromArray:[tmpOthers sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
	}
	
	free(alreadyUsed);
}

- (float)currentValueForKey:(NSString *)locationKey {
	NSDictionary *tmpDictionary = sensorData[locationKey];
	if (tmpDictionary == nil) return 0;
	
    NSNumber *n = tmpDictionary[GSCurrentValueKey];
    
    if (n != nil) {
        return [n floatValue];
    }
    else {
        return 0;
    }
}

- (void)setCurrentValue:(float)value andUnits:(NSString *)units forLocation:(NSString *)location {
	bool needRegen = NO;
	
	// Need to find the right dictionary for this location
	NSMutableDictionary *valueDictionary = sensorData[location];
	
	// If we didn't find it, we need to create a new one and insert it into our collection.
	if (valueDictionary == nil) {
		valueDictionary = [NSMutableDictionary dictionaryWithCapacity:10];
		sensorData[location] = valueDictionary;
		needRegen = YES;
	}
	
	// Set the units
	valueDictionary[GSUnitsKey] = units;
		
	// Set the current value in the sensor data dictionary
	valueDictionary[GSCurrentValueKey] = @(value);
	
	// Set that this sensor is enabled.
	valueDictionary[GSEnable] = @"YES";
	
	// Set the next value in the data set.
	if (valueDictionary[GSDataSetKey] == nil) {
		// we have to create an XRGDataSet for this location.
		XRGDataSet *newSet = [[[XRGDataSet alloc] init] autorelease];
		[newSet resize:(size_t)numSamples];
		[newSet setAllValues:value];
		valueDictionary[GSDataSetKey] = newSet;
	}
	[valueDictionary[GSDataSetKey] setNextValue:value];
	
	// If this location doesn't have a label, generate one.
	if (valueDictionary[GSLabelKey] == nil) {
		if ([location isEqualToString:@"CPU A AD7417 AMB"]) {
			valueDictionary[GSLabelKey] = @"CPU A Ambient";
		}
		else if ([location isEqualToString:@"CPU B AD7417 AMB"]) {
			valueDictionary[GSLabelKey] = @"CPU B Ambient";
		}
		else {
			valueDictionary[GSLabelKey] = location;
		}
	}
				
	
	// Regenerate our location keys if needed
	if (needRegen) [self regenerateLocationKeyOrder];
	
	#ifdef DEBUG
		NSLog(@"Set current value: %f (%@) for location: (%@)", value, units, locationKey);
	#endif
	
	return;
}

- (XRGDataSet *)dataSetForKey:(NSString *)locationKey {
	NSDictionary *tmpDictionary = sensorData[locationKey];
	if (tmpDictionary == nil) return nil;

    return tmpDictionary[GSDataSetKey];
}

- (NSString *)labelForKey:(NSString *)locationKey {
    id label = sensorData[locationKey][GSLabelKey];
    
    if (label == nil) {
        return locationKey;
    }
    else {
        return label;
    }
}

- (void)setDataSize:(int)newNumSamples {
    NSArray *a = [sensorData allKeys];

    int i;
    for (i = 0; i < [a count]; i++) {
		[sensorData[a[i]][GSDataSetKey] resize:(size_t)newNumSamples];
    }
    
    numSamples = newNumSamples;
}

@end

//
//  ORXYCom564Decoder.m
//  Orca
//
//  Created by Michael Marino 31 Oct 2011
//  Copyright 2008 CENPA, University of Washington. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//Washington at the Center for Experimental Nuclear Physics and 
//Astrophysics (CENPA) sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//Washington reserve all rights in the program. Neither the authors,
//University of Washington, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------


#import "ORXYCom564Decoder.h"
#import "ORDataPacket.h"
#import "ORDataSet.h"
#import "ORDataTypeAssigner.h"
#import "ORIP320Model.h"


@implementation ORXYCom564Decoder

- (unsigned long) decodeData:(void*)someData fromDecoder:(ORDecoder*)aDecoder intoDataSet:(ORDataSet*)aDataSet
{
    unsigned long* ptr	 = (unsigned long*)someData;
    unsigned long length = ExtractLength(*ptr);
	ptr++;
	unsigned char crate  = (*ptr&0x01e00000)>>21;
	unsigned char card   = (*ptr& 0x001f0000)>>16;
	NSString* crateKey	 = [self getCrateKey: crate];
	NSString* cardKey	 = [self getCardKey: card];
	
	ptr++; //point to time
	unsigned long theTime = *ptr;
    ptr++; // skip the microseconds 

	int n = length - 4;
	int i;
	for(i=0;i<n;i++){
		ptr++;	//channel
		int chan   = (*ptr>>16) & 0x000000ff;
		long rawValue = (*ptr & 0x0000ffff);
		[aDataSet loadTimeSeries:rawValue atTime:theTime sender:self withKeys:@"XYCom564",@"Time Series",crateKey,cardKey,[self getChannelKey:chan],nil];
        [aDataSet histogram:rawValue numBins:0xffff sender:self  withKeys:@"XYCom564", @"Hist",crateKey,cardKey,[self getChannelKey:chan],nil];
    }


    return length; //must return number of longs processed.
}

- (NSString*) dataRecordDescription:(unsigned long*)ptr
{
    unsigned long length = ExtractLength(*ptr);
    NSString* title= @"ORXYCom564 ADC Record\n\n";

	ptr++;
    NSString* crate			= [NSString stringWithFormat:@"Crate = %lu\n",(*ptr&0x01e00000)>>21];
    NSString* card			= [NSString stringWithFormat:@"Card  = %lu\n",(*ptr&0x001f0000)>>16];

	ptr++;
	NSDate* date = [NSDate dateWithTimeIntervalSince1970:*ptr];

	NSString* adcString = @"";
	int n = length - 3;
	int i;
	for(i=0;i<n;i++){
		ptr++;
		adcString   = [adcString stringByAppendingFormat:@"ADC(%02lu) = 0x%lx\n",(*ptr>>16)&0x000000ff, *ptr&0x00000fff];
    }

    return [NSString stringWithFormat:@"%@%@%@%@%@",title,crate,card,[date descriptionFromTemplate:@"MM/dd/yy HH:mm:ss z\n"],adcString];
}


@end

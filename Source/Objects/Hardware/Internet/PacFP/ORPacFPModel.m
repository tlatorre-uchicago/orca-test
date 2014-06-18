//--------------------------------------------------------
// ORPacFPModel
// Created by Mark  A. Howe on Mon Jun 16, 2014
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2014, University of North Carolina. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//North Carolina sponsored in part by the United States
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//North Carolina reserve all rights in the program. Neither the authors,
//University of North Carolina, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#pragma mark •••Imported Files

#import "ORPacFPModel.h"
#import "ORDataTypeAssigner.h"
#import "ORDataPacket.h"
#import "ORDataSet.h"
#import "ORTimeRate.h"
#import "ORSafeQueue.h"
#import "NetSocket.h"

#pragma mark •••External Strings

NSString* ORPacFPModelIpConnectedChanged       = @"ORPacFPModelIpConnectedChanged";
NSString* ORPacFPModelIpAddressChanged         = @"ORPacFPModelIpAddressChanged";

NSString* ORPacFPModelLastGainReadChanged   = @"ORPacFPModelLastGainReadChanged";
NSString* ORPacFPModelAdcChannelChanged     = @"ORPacFPModelAdcChannelChanged";
NSString* ORPacFPModelLcmChanged            = @"ORPacFPModelLcChanged";
NSString* ORPacFPModelProcessLimitsChanged  = @"ORPacFPModelProcessLimitsChanged";
NSString* ORPacFPModelGainDisplayTypeChanged = @"ORPacFPModelGainDisplayTypeChanged";
NSString* ORPacFPModelAdcChanged            = @"ORPacFPModelAdcChanged";
NSString* ORPacFPModelGainsChanged          = @"ORPacFPModelGainsChanged";
NSString* ORPacFPModelPollingStateChanged	= @"ORPacFPModelPollingStateChangedNotification";
NSString* ORPacFPModelLogToFileChanged      = @"ORPacFPModelLogToFileChanged";
NSString* ORPacFPModelLogFileChanged		= @"ORPacFPModelLogFileChanged";
NSString* ORPacFPModelQueCountChanged		= @"ORPacFPModelQueCountChanged";
NSString* ORPacFPModelGainsReadBackChanged  = @"ORPacFPModelGainsReadBackChanged";
NSString* ORPacFPLock						= @"ORPacFPLock";

@interface ORPacFPModel (private)
- (void) timeout;
- (void) processOneCommandFromQueue;
- (void) _setUpPolling:(BOOL)verbose;
- (void) _stopPolling;
- (void) _startPolling;
- (void) _pollAllChannels;
- (void) shipAdcValues;
- (void) loadLogBuffer;
@end

#define kBadPacFPValue -999
#define kPacFPPort 12340

@implementation ORPacFPModel

- (void) dealloc
{
    [lastGainRead release];
    [lastGainFile release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [buffer release];
	[cmdQueue release];
	[lastRequest release];
    
    if([self isConnected]){
        [socket close];
        [socket setDelegate:nil];
        [socket release];
    }
	
    [ipAddress release];

    [logFile release];
	[self _stopPolling];
	
	int i;
	for(i=0;i<8;i++){
		[timeRates[i] release];
	}
	[processLimits release];
	
	[[ORGlobal sharedGlobal] removeRunVeto:@"LCM Enabled"];
	
	[super dealloc];
}

- (void) wakeUp
{
    if(![self aWake]){
		//[self _setUpPolling:NO];
		if(logToFile){
			[self performSelector:@selector(writeLogBufferToFile) withObject:nil afterDelay:60];		
		}
    }
    [super wakeUp];
}

- (void) sleep
{
	[[ORGlobal sharedGlobal] removeRunVeto:@"LCM Enabled"];
    [super sleep];
   // [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void) setUpImage
{
	[self setImage:[NSImage imageNamed:@"PacFP.tif"]];

}

- (void) makeMainController
{
	[self linkToController:@"ORPacFPController"];
}

#pragma mark •••Accessors

- (NSString*) title
{
    return [NSString stringWithFormat:@"%@ (%@)",[self fullID],[self ipAddress]];
}

- (BOOL) wasConnected
{
    return wasConnected;
}

- (void) setWasConnected:(BOOL)aState
{
    wasConnected = aState;
}


- (NetSocket*) socket
{
	return socket;
}
- (void) setSocket:(NetSocket*)aSocket
{
	if(aSocket != socket)[socket close];
	[aSocket retain];
	[socket release];
	socket = aSocket;
    [socket setDelegate:self];
}

- (BOOL) ipConnected
{
    return ipConnected;
}

- (void) setIpConnected:(BOOL)aIpConnected
{
    ipConnected  = aIpConnected;
	wasConnected = ipConnected;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelIpConnectedChanged object:self];
}

- (NSString*) ipAddress
{
    return ipAddress;
}

- (void) setIpAddress:(NSString*)aIpAddress
{
	if(!aIpAddress)aIpAddress = @"";
    [[[self undoManager] prepareWithInvocationTarget:self] setIpAddress:ipAddress];
    
    [ipAddress autorelease];
    ipAddress = [aIpAddress copy];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelIpAddressChanged object:self];
    
    if(wasConnected){
        [self connectIP];
    }
}

- (void) connectIP
{
	if(![self isConnected] && [ipAddress length]){
		[self setSocket:[NetSocket netsocketConnectedToHost:ipAddress port:kPacFPPort]];
        [self setIpConnected:[socket isConnected]];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelIpConnectedChanged object:self];

	}
}

- (BOOL) isConnected
{
    return ipConnected;
}

- (void) netsocketConnected:(NetSocket*)inNetSocket
{
    if(inNetSocket == socket){
        [self setIpConnected:[socket isConnected]];
    }
}

- (void) netsocket:(NetSocket*)inNetSocket dataAvailable:(unsigned)inAmount
{
    if(!lastRequest)return;
    
    if(inNetSocket == socket){
		NSString* theString = [[[[NSString alloc] initWithData:[inNetSocket readData] encoding:NSASCIIStringEncoding] autorelease] uppercaseString];
        if(!inputBuffer)inputBuffer = [[NSMutableString alloc]initWithString:theString];
        else [inputBuffer appendString:theString];
        
        [self parseString:inputBuffer];
        [self clearInputBuffer];
    }
}

- (void) clearInputBuffer
{
    [inputBuffer release];
    inputBuffer = nil;
}

- (void) netsocketDisconnected:(NetSocket*)inNetSocket
{
    if(inNetSocket == socket){
        [self setIpConnected:NO];
		[socket autorelease];
		socket = nil;
    }
}

- (void) parseString:(NSString*)theString
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeout) object:nil];
    if([lastRequest hasPrefix:@"get gains"]){
        NSArray* theParts = [theString componentsSeparatedByString:@","];
        int i=0;
        for(id aValue in theParts){
            [self setGainReadBack:i withValue:[aValue intValue]];
            i++;
        }
    }
    else if([lastRequest hasPrefix:@"set gains"]){
        //nothing to do
    }

    else if([lastRequest hasPrefix:@"get temperatures"]){
        NSArray* theParts = [theString componentsSeparatedByString:@","];
        int i=0;
        for(id aValue in theParts){
            [self setAdc:i value:[aValue floatValue]];
            i++;
        }
    }
    else if([lastRequest hasPrefix:@"get current"]){
        [self setLcm:[theString intValue]];
    }
}

- (NSDate*) lastGainRead
{
    return lastGainRead;
}

- (void) setLastGainRead:(NSDate*)aLastGainRead
{
    [aLastGainRead retain];
    [lastGainRead release];
    lastGainRead = aLastGainRead;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelLastGainReadChanged object:self];
}

- (unsigned short) lcmTimeMeasured
{
    return lcmTimeMeasured;
}

- (unsigned short) lcm
{
    return lcm;
}

- (void) setLcm:(unsigned short)aLcm
{
    lcm = aLcm;
    //get the time(UT!)
    time_t	ut_Time;
    time(&ut_Time);
    //struct tm* theTimeGMTAsStruct = gmtime(&theTime);
    lcmTimeMeasured = ut_Time;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelLcmChanged object:self];
}

- (NSMutableArray*) processLimits
{
    return processLimits;
}

- (NSString*) lastGainFile
{
    return lastGainFile;
}

- (void) setLastGainFile:(NSString*)aLastGainFile
{
    [lastGainFile autorelease];
    lastGainFile = [aLastGainFile copy];    
}

- (int) gainDisplayType
{
    return gainDisplayType;
}

- (void) setGainDisplayType:(int)aGainDisplayType
{
    [[[self undoManager] prepareWithInvocationTarget:self] setGainDisplayType:gainDisplayType];
    gainDisplayType = aGainDisplayType;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelGainDisplayTypeChanged object:self];
}

- (int) queCount
{
	return [cmdQueue count];
}


- (ORTimeRate*)timeRate:(int)index
{
	return timeRates[index];
}

- (int)  gain:(int)index
{
	if(index>=0 && index<148)return gain[index];
	else return 0;
}

- (void) setGain:(int)index withValue:(int)aValue
{
	if(index>=0 && index<148){
		[[[self undoManager] prepareWithInvocationTarget:self] setGain:index withValue:gain[index]];
		gain[index] = aValue;
		[[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelGainsChanged object:self];
	}
}

- (int)  gainReadBack:(int)index
{
	if(index>=0 && index<148)return gainReadBack[index];
	else return 0;
}

- (void) setGainReadBack:(int)index withValue:(int)aValue
{
	if(index>=0 && index<148){
		gainReadBack[index] = aValue;
		[[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelGainsReadBackChanged object:self];
	}
}

- (float) lcmVoltage
{
	return 5.0 * lcm/65535.0;
}

- (float) adcVoltage:(int)index
{
	if(index<0 && index>=8)return 0.0;
	else return 5.0 * adc[index]/65535.0;
}

- (float) convertedLcm
{
 	float theValue = kBadPacFPValue; //a 'bad' value as default
	@synchronized (self){
        float leakageCurrentConstants[2] = {1.0	,	0.0};
        float voltage = [self lcmVoltage];
        theValue = voltage * leakageCurrentConstants[0] + leakageCurrentConstants[1];
    }
    return theValue;
}

- (float) convertedAdc:(int)index
{
	float theValue = kBadPacFPValue; //a 'bad' value as default
	@synchronized (self){
		if(index<0 && index>8)return 0.0;
                
		float temperatureConstants[8][2] = {
			{100.0	,	-50.0},
			{1.0	,	0.0},
			{1.0	,	0.0},
			{1.0	,	0.0},
			{1.0	,	0.0},
			{1.0	,	0.0},
			{86.141	,	-100},
			{1.0	,	0.0},
		};
        
		float voltage = [self adcVoltage:index];
		if(index>=0 && index<8) {
            theValue = voltage * temperatureConstants[index][0] + temperatureConstants[index][1];
        }
	}
	return theValue;
}

- (unsigned short) adc:(int)index
{
	if(index>=0 && index<8)return adc[index];
	else return 0.0;
}

- (void) setAdc:(int)index value:(unsigned short)aValue
{
	if(index>=0 && index<8){
		adc[index] = aValue;
		//get the time(UT!)
		time_t	ut_Time;
		time(&ut_Time);
		//struct tm* theTimeGMTAsStruct = gmtime(&theTime);
		timeMeasured[index] = ut_Time;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelAdcChanged 
															object:self 
														userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"]];

		if(timeRates[index] == nil) timeRates[index] = [[ORTimeRate alloc] init];
		[timeRates[index] addDataToTimeAverage:[self convertedAdc:index]];
	}
}

- (NSString*) lastRequest
{
	return lastRequest;
}

- (void) setLastRequest:(NSString*)aRequest
{
	[aRequest retain];
	[lastRequest release];
	lastRequest = aRequest;    
}


- (NSString*) logFile
{
    return logFile;
}

- (void) setLogFile:(NSString*)aLogFile
{
    [[[self undoManager] prepareWithInvocationTarget:self] setLogFile:logFile];
	
    [logFile autorelease];
    logFile = [aLogFile copy];    
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelLogFileChanged object:self];
}

- (BOOL) logToFile
{
    return logToFile;
}

- (void) setLogToFile:(BOOL)aLogToFile
{
    [[[self undoManager] prepareWithInvocationTarget:self] setLogToFile:logToFile];
    
    logToFile = aLogToFile;
	
	if(logToFile)[self performSelector:@selector(writeLogBufferToFile) withObject:nil afterDelay:60];
	else {
		[logBuffer removeAllObjects];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(writeLogBufferToFile) object:nil];
	}
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelLogToFileChanged object:self];
}

- (void) writeLogBufferToFile
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(writeLogBufferToFile) object:nil];
	if(logToFile && [logBuffer count] && [logFile length]){
		if(![[NSFileManager defaultManager] fileExistsAtPath:[logFile stringByExpandingTildeInPath]]){
			[[NSFileManager defaultManager] createFileAtPath:[logFile stringByExpandingTildeInPath] contents:nil attributes:nil];
		}
		
		NSFileHandle* fh = [NSFileHandle fileHandleForUpdatingAtPath:[logFile stringByExpandingTildeInPath]];
		[fh seekToEndOfFile];
		
		int i;
		int n = [logBuffer count];
		for(i=0;i<n;i++){
			[fh writeData:[[logBuffer objectAtIndex:i] dataUsingEncoding:NSASCIIStringEncoding]];
		}
		[fh closeFile];
		[logBuffer removeAllObjects];
	}
	[self performSelector:@selector(writeLogBufferToFile) withObject:nil afterDelay:60];
}


#pragma mark •••Archival
- (id) initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];

	[[self undoManager] disableUndoRegistration];
    
    processLimits = [[decoder decodeObjectForKey:@"processLimits"]retain];
    if(!processLimits)[self setProcessLimitDefaults];
    //--------------------------------------------------------------
	[self setLastGainFile:	[decoder decodeObjectForKey: @"lastGainFile"]];
	[self setGainDisplayType:[decoder decodeIntForKey:   @"gainDisplayType"]];
	[self setWasConnected:	[decoder decodeBoolForKey:	 @"wasConnected"]];
	[self setPollingState:	[decoder decodeIntForKey:	 @"pollingState"]];
	[self setLogFile:		[decoder decodeObjectForKey: @"logFile"]];
    [self setLogToFile:		[decoder decodeBoolForKey:	 @"logToFile"]];
	
    [self setIpAddress:[decoder decodeObjectForKey:@"ORPacFPModelIpAddress"]];
    
    int i;
	for(i=0;i<8;i++){
		timeRates[i] = [[ORTimeRate alloc] init];
	}
	for(i=0;i<148;i++){
		[self setGain:i withValue: [decoder decodeIntForKey:[NSString stringWithFormat:@"gain%d",i]]];
	}
    
	[[self undoManager] enableUndoRegistration];

	return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeObject:processLimits     forKey:@"processLimits"];
    [encoder encodeObject:lastGainFile  forKey:@"lastGainFile"];
    [encoder encodeInt:gainDisplayType  forKey:@"gainDisplayType"];
    [encoder encodeInt:pollingState		forKey:@"pollingState"];
    [encoder encodeObject:logFile		forKey:@"logFile"];
    [encoder encodeBool:logToFile		forKey:@"logToFile"];

    [encoder encodeBool:wasConnected	forKey:@"wasConnected"];
    
    [encoder encodeObject:ipAddress     forKey:@"ORPacFPModelIpAddress"];

    int i;
	for(i=0;i<148;i++){
		[encoder encodeInt:gain[i] forKey: [NSString stringWithFormat:@"gain%d",i]];
	}
}

#pragma mark ••• Commands
- (void) getGains
{
    if([self isConnected]){
        [self writeCmdString:@"get gains"];
    }
}
- (void) setGains
{
    if([self isConnected]){
        NSMutableString* cmd = [NSMutableString stringWithString:@"set gains"];
        [cmd appendString:@":"];
        int i;
        for(i=0;i<148;i++){
            [cmd appendFormat:@"%d",gain[i]];
            if(i!=147)[cmd appendString:@","];
        }
        [self writeCmdString:cmd];
    }
}
- (void) getTemperatures
{
    if([self isConnected]){
        [self writeCmdString:@"get temperatures"];
        [self writeShipCmd];
    }
}
- (void) getCurrent
{
    if([self isConnected]){
        [self writeCmdString:@"get current"];
        [self writeShipCmd];
    }
}

- (void) writeShipCmd
{
    if([self isConnected]){
		[self writeCmdString:@"++ShipData"];
	}
}

- (void) readAdcs
{
    [self getTemperatures];
    [self getCurrent];
}

- (void) writeCmdString:(NSString*)aCommand
{
	if(!cmdQueue)cmdQueue = [[ORSafeQueue alloc] init];
    if(![aCommand hasSuffix:@"\n"])aCommand = [NSString stringWithFormat:@"%@\n",aCommand];
	[cmdQueue enqueue:aCommand];
	[[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelQueCountChanged object: self];
	if(!lastRequest)[self processOneCommandFromQueue];
}


#pragma mark •••Data Records
- (unsigned long) dataId { return dataId; }
- (void) setDataId: (unsigned long) DataId
{
    dataId = DataId;
}
- (void) setDataIds:(id)assigner
{
    dataId       = [assigner assignDataIds:kLongForm];
}

- (void) syncDataIdsWith:(id)anotherPacFP
{
    [self setDataId:[anotherPacFP dataId]];
}

- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(id)userInfo
{
    //----------------------------------------------------------------------------------------
    // first add our description to the data description
    [aDataPacket addDataDescriptionItem:[self dataRecordDescription] forKey:@"PacFPModel"];
}

- (NSDictionary*) dataRecordDescription
{
    NSMutableDictionary* dataDictionary = [NSMutableDictionary dictionary];
    NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"ORPacFPDecoderForAdc",				@"decoder",
        [NSNumber numberWithLong:dataId],   @"dataId",
        [NSNumber numberWithBool:NO],       @"variable",
        [NSNumber numberWithLong:8],        @"length",
        nil];
    [dataDictionary setObject:aDictionary forKey:@"Adcs"];
    
    return dataDictionary;
}


- (unsigned long) timeMeasured:(int)index
{
	if(index<0)return 0;
	else if(index>=8)return 0;
	else return timeMeasured[index];
}

- (NSMutableDictionary*) addParametersToDictionary:(NSMutableDictionary*)dictionary
{
    NSMutableDictionary* objDictionary = [NSMutableDictionary dictionary];
    [objDictionary setObject:NSStringFromClass([self class]) forKey:@"Class Name"];
    if([lastGainFile length])[objDictionary setObject:lastGainFile forKey:@"RDAC File"];

	NSMutableArray* gainArray = [NSMutableArray array];
	int i;
	for(i=0;i<148;i++){
		[gainArray addObject:[NSNumber numberWithInt:gain[i]]];
	}
	
    [objDictionary setObject:gainArray forKey:@"gain"];
	
	[dictionary setObject:objDictionary forKey:[self identifier]];
    	
	return objDictionary;
}

- (void) setPollingState:(NSTimeInterval)aState
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPollingState:pollingState];
    
    pollingState = aState;
    
    [self performSelector:@selector(_startPolling) withObject:nil afterDelay:0.5];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelPollingStateChanged object: self];
}

- (NSTimeInterval)	pollingState
{
    return pollingState;
}

- (void) readGainFile:(NSString*) aPath
{
	[self setLastGainFile:aPath];
	NSString* contents = [NSString stringWithContentsOfFile:[aPath stringByExpandingTildeInPath] encoding:NSASCIIStringEncoding error:nil];
	contents = [contents stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
	NSArray* lines = [contents componentsSeparatedByString:@"\n"];
	for(id aLine in lines){
		aLine = [aLine stringByReplacingOccurrencesOfString:@" " withString:@""];
		NSArray* parts = [aLine componentsSeparatedByString:@","];
		if([parts count] == 5){
			int index = [[parts objectAtIndex:0] intValue];
			if(index < 38){
				gain[index]			= [[parts objectAtIndex:1] intValue]; 
				gain[index+37]		= [[parts objectAtIndex:2] intValue]; 
				gain[index+2*37]	= [[parts objectAtIndex:3] intValue]; 
				gain[index+3*37]	= [[parts objectAtIndex:4] intValue]; 
			}
		}
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelGainsChanged object:self];
}

- (void) saveGainFile:(NSString*) aPath
{
	NSString* fullFileName = [aPath stringByExpandingTildeInPath];
	int i;
	NSString* s = @"";
	for(i=0;i<37;i++){
		s = [s stringByAppendingFormat:@"%d,%d,%d,%d,%d\n",i,gain[i],gain[i+37],gain[i+2*37],gain[i+3*37]];
	}
	
	[s writeToFile:fullFileName atomically:NO encoding:NSASCIIStringEncoding error:nil];

}
#pragma mark •••Bit Processing Protocol
- (void) processIsStarting
{
	[self _stopPolling];
    readOnce = NO;
}

- (void) processIsStopping
{
	[self _startPolling];
}

//note that everything called by these routines MUST be threadsafe
- (void) startProcessCycle
{    
	if(!readOnce){
		@try { 
			if([cmdQueue count] == 0) {
				[self performSelectorOnMainThread:@selector(readAdcs) withObject:nil waitUntilDone:NO];
				readOnce = YES;
			}
		}
		@catch(NSException* localException) { 
			//catch this here to prevent it from falling thru, but nothing to do.
		}
	}	
}

- (void) endProcessCycle
{
    readOnce = NO;
}

- (NSString*) identifier
{
	NSString* s;
 	@synchronized(self){
		s= [NSString stringWithFormat:@"PacFP,%lu",[self uniqueIdNumber]];
	}
	return s;
}

- (NSString*) processingTitle
{
	NSString* s;
 	@synchronized(self){
		s= [self identifier];
	}
	return s;
}

- (NSString*)adcName:(int)aChan
{
    switch (aChan){
        case 0: return @"Gen Temp"; 
        case 1: return @"Bias V."; 
        case 2: return @"Free"; 
        case 3: return @"Free"; 
        case 4: return @"LCM";
        case 5: return @"Free"; 
        case 6: return @"Carousel T1"; 
        case 7: return @"Carousel T2"; 
        default: return @"";
    }
}

- (NSString*)processName:(int)aChan
{
    switch (aChan){
        case 0: return @"Gen Temp"; 
        case 1: return @"Bias V."; 
        case 2: return @"Carousel T1"; 
        case 3: return @"Carousel T2"; 
        case 4: return @"LCM"; 
        default: return @"";
    }
}

- (double) convertedValue:(int)aChan
{
	double theValue;
	@synchronized(self){
        switch (aChan){
            case 0: theValue =  [self convertedAdc:0];  break;
            case 1: theValue =  [self convertedAdc:1];  break;
            case 2: theValue =  [self convertedAdc:6];  break;
            case 3: theValue =  [self convertedAdc:7];  break;
            case 4: theValue =  [self lcmVoltage];      break;
            default:theValue = 0;                       break;
        }
	}
	return theValue;
}

- (double) maxValueForChan:(int)aChan
{
	double theValue;
	@synchronized(self){
        if(aChan>=0 && aChan<8) theValue = [[[processLimits objectAtIndex:aChan] objectForKey:@"HiLimit"]doubleValue];
		else         theValue = 100.0;
	}
	return theValue;
}

- (double) minValueForChan:(int)aChan
{
	double theValue;
	@synchronized(self){
        if(aChan>=0 && aChan<8) theValue = [[[processLimits objectAtIndex:aChan] objectForKey:@"LoLimit"]doubleValue];
		else         theValue = 100.0;
	}
	return theValue;
}

- (void) getAlarmRangeLow:(double*)theLoAlarm high:(double*)theHighAlarm channel:(int)aChan
{
	@synchronized(self){
        if([self convertedValue:aChan] == kBadPacFPValue){
            *theLoAlarm = -999;
            *theHighAlarm = 999999;
        }
        else if(aChan>=0 && aChan<8) {
            *theLoAlarm = [[[processLimits objectAtIndex:aChan] objectForKey:@"LoAlarm"]doubleValue];
            *theHighAlarm = [[[processLimits objectAtIndex:aChan] objectForKey:@"HiAlarm"]doubleValue];
        }
        else {
            *theHighAlarm = 100;
            *theLoAlarm = -.001;
        }
	}		
}

- (BOOL) processValue:(int)channel
{
	BOOL r;
	@synchronized(self){
        if(channel==0)      return [self isConnected];
        else return NO;
    }
	return r;
}

- (void) setProcessOutput:(int)channel value:(int)value
{
    //nothing to do. not used in adcs. really shouldn't be in the protocol
}
- (void) setProcessLimitDefaults
{
    [processLimits release];
    processLimits = [[NSMutableArray array] retain];
    NSMutableDictionary* entry;
    //entry 0 Gen Temp
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-50],@"LoAlarm",  
             [NSNumber numberWithFloat:100],@"HiAlarm", 
             [NSNumber numberWithFloat:-30],@"LoLimit",  
             [NSNumber numberWithFloat:70], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
    //entry 1 Bias V
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-50],@"LoAlarm",  
             [NSNumber numberWithFloat:100],@"HiAlarm", 
             [NSNumber numberWithFloat:-30],@"LoLimit",  
             [NSNumber numberWithFloat:70], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
    //entry 2 PreAmp T
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-50],@"LoAlarm",  
             [NSNumber numberWithFloat:100],@"HiAlarm", 
             [NSNumber numberWithFloat:-30],@"LoLimit",  
             [NSNumber numberWithFloat:70], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
    //entry 3 Carrousel T
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-50],@"LoAlarm",  
             [NSNumber numberWithFloat:100],@"HiAlarm", 
             [NSNumber numberWithFloat:-30],@"LoLimit",  
             [NSNumber numberWithFloat:70], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
    //entry 4 LCM
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-1],@"LoAlarm",  
             [NSNumber numberWithFloat:5],@"HiAlarm", 
             [NSNumber numberWithFloat:0],@"LoLimit",  
             [NSNumber numberWithFloat:5], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
    //entry 5 Module
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-1],@"LoAlarm",  
             [NSNumber numberWithFloat:32],@"HiAlarm", 
             [NSNumber numberWithFloat:0],@"LoLimit",  
             [NSNumber numberWithFloat:31], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
    //entry 6 Preamp
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-1],@"LoAlarm",  
             [NSNumber numberWithFloat:8],@"HiAlarm", 
             [NSNumber numberWithFloat:0],@"LoLimit",  
             [NSNumber numberWithFloat:7], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
    //entry 7 Adc Chan
    entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithFloat:-1],@"LoAlarm",  
             [NSNumber numberWithFloat:148],@"HiAlarm", 
             [NSNumber numberWithFloat:0],@"LoLimit",  
             [NSNumber numberWithFloat:147], @"HiLimit", 
             nil];
    [processLimits addObject:entry];
}

@end

@implementation ORPacFPModel (private)

- (void) shipAdcValues
{
    if([[ORGlobal sharedGlobal] runInProgress]){
		
		unsigned long data[18];
		data[0] = dataId | 18;
		data[1] = ([self uniqueIdNumber]&0xfff);
		
		int index = 2;
		int i;
		for(i=0;i<8;i++){
			data[index++] = adc[i];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:ORQueueRecordForShippingNotification 
															object:[NSData dataWithBytes:data length:sizeof(long)*18]];
	}
}
- (void) loadLogBuffer
{
	NSString*   outputString = nil;
	if(logToFile) {
		outputString = [NSString stringWithFormat:@"%lu ",timeMeasured[0]];
		short chan;
		for(chan=0;chan<8;chan++){
			outputString = [outputString stringByAppendingFormat:@"%.2f ",[self convertedAdc:chan]];
		}
		outputString = [outputString stringByAppendingString:@"\n"];
		//accumulate into a buffer, we'll write the file later
		if(!logBuffer)logBuffer = [[NSMutableArray arrayWithCapacity:1024] retain];
		if([outputString length]){
			[logBuffer addObject:outputString];
		}
	}
	readCount++;	
}
- (void) timeout
{
	@synchronized (self){
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeout) object:nil];
		NSLogError(@"command timeout",@"PAC",nil);
		[self setLastRequest:nil];
		[cmdQueue removeAllObjects]; //if we timeout we just flush the queue
		[[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelQueCountChanged object: self];
		//[self processOneCommandFromQueue];	 //do the next command in the queue
		gainIndex = 0;
	}
}

- (void) processOneCommandFromQueue
{
	if([cmdQueue count] > 0){
		NSString* cmd = [cmdQueue dequeue];
		[[NSNotificationCenter defaultCenter] postNotificationName:ORPacFPModelQueCountChanged object: self];
		if([cmd isEqualToString:@"++ShipData"]){
			[self setLastRequest:nil];
			[self shipAdcValues];
			[self loadLogBuffer];
			[self processOneCommandFromQueue];
		}
		else {
			[self setLastRequest:cmd];
            [socket writeString:cmd encoding:NSASCIIStringEncoding];
			[self performSelector:@selector(timeout) withObject:nil afterDelay:1];
		}
	}
}

- (void) _stopPolling
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_pollAllChannels) object:nil];
	pollRunning = NO;
}

- (void) _startPolling
{
	[self _setUpPolling:YES];
}

- (void) _setUpPolling:(BOOL)verbose
{
    if(pollingState!=0){  
		readCount = 0;
		pollRunning = YES;
        if(verbose)NSLog(@"Polling PAC,%d  every %.0f seconds.\n",[self uniqueIdNumber],pollingState);
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_pollAllChannels) object:nil];
        [self _pollAllChannels];
    }
    else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_pollAllChannels) object:nil];
        if(verbose)NSLog(@"Not Polling PAC,%d\n",[self uniqueIdNumber]);
    }
}

- (void) _pollAllChannels
{
	float nextTry = pollingState;
    @try { 
		if([cmdQueue count] == 0)[self readAdcs];
		else nextTry = .5;
    }
	@catch(NSException* localException) { 
		//catch this here to prevent it from falling thru, but nothing to do.
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_pollAllChannels) object:nil];
	if(pollingState!=0){
		[self performSelector:@selector(_pollAllChannels) withObject:nil afterDelay:nextTry];
	}
}

@end
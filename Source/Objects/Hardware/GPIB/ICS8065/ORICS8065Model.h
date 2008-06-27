//
//  ORICS8065Model.h
//  Orca
//
//  Created by Mark Howe on Friday, June 20, 2008.
//  Copyright (c) 2003 CENPA, University of Washington. All rights reserved.
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

#import "vxi11.h"
#define kMaxGpibAddresses 	31
#define kNumBoards 2
#define kNotInitialized		-1
#define kDefaultGpibPort 0


#pragma mark ***Errors
#define OExceptionGpibError	@"GPIBError"

#import "EduWashingtonNplOrcaNi488PlugIn.h"

#pragma mark ***Class Definition
@interface ORICS8065Model : OrcaObject {
    NSString* ipAddress;
    BOOL isConnected;
	CLIENT* rpcClient;
	
    Create_LinkResp             mDeviceLink[ kMaxGpibAddresses ];
    short                       mDeviceSecondaryAddress[ kMaxGpibAddresses ];  
    NSMutableString*            mErrorMsg;  
    NSRecursiveLock*            theHWLock;
	bool                        mMonitorRead;
	bool                        mMonitorWrite;
    ORAlarm*                    noDriverAlarm;
    ORAlarm*                    noPluginAlarm;
    EduWashingtonNplOrcaNi488PlugIn*  iCS8065Instance;
}

#pragma mark ***Initialization.
- (void)	commonInit;
- (id) 		init;
- (void) 	dealloc;
- (void) 	makeConnectors;
- (NSString*) pluginName;

#pragma mark ***Accessors
- (CLIENT*) rpcClient;
- (void) setRpcClient:(CLIENT*)anRpcClient;
- (BOOL)	isConnected;
- (void)	setIsConnected:(BOOL)aFlag;
- (NSString*) ipAddress;
- (void)	setIpAddress:(NSString*)aIpAddress;
- (BOOL)    isEnabled;
- (int) 	ibsta;
- (int)		iberr;
- (long)	ibcntl;
- (NSMutableString*)	errorMsg;
- (void)	connect;

#pragma mark ***Commands
- (void) 	changePrimaryAddress: (short) anOldPrimaryAddress newAddress: (short) aNewPrimaryAddress;
- (void) 	changeState: (short) aPrimaryAddress online: (BOOL) aState;
- (BOOL) 	checkAddress: (short) aPrimaryAddress;
- (void) 	deactivateAddress: (short) aPrimaryAddress;
- (void) 	resetDevice: (short) aPrimaryAddress;
- (void) 	setupDevice: (short) aPrimaryAddress secondaryAddress: (short) aSecondaryAddress;
- (long) 	readFromDevice: (short) aPrimaryAddress data: (char*) aData 
                                               maxLength: (long) aMaxLength;
- (void) 	writeToDevice: (short) aPrimaryAddress command: (NSString*) aCommand;
- (long) 	writeReadDevice: (short) aPrimaryAddress command: (NSString*) aCommand data: (char*) aData
                                                   maxLength: (long) aMaxLength;

- (void) 	enableEOT:(short)aPrimaryAddress state: (BOOL) state;
- (void) 	wait: (short) aPrimaryAddress mask: (short) aWaitMask;


- (void)	checkDeviceThrow: (short) aPrimaryAddress;
- (void)	checkDeviceThrow: (short) aPrimaryAddress checkSetup: (BOOL) aState;
- (void)	gpibError: (NSMutableString*) aMsg number:(int)errNum;
- (id) 		getGpibController;
- (void)	setGPIBMonitorRead: (bool) aMonitorRead;
- (void)	setGPIBMonitorWrite: (bool) aMonitorWrite;

@end

#pragma mark ***Notification string definitions.
extern NSString* ORGpib1MonitorNotification;
extern NSString* ORICS8065TestLock;
extern NSString* ORGPIB1BoardChangedNotification;
extern NSString* ORICS8065ModelIsConnectedChanged;
extern NSString* ORICS8065ModelIpAddressChanged;

#pragma mark ***Other string definitions.
extern NSString*	ORGpib1Monitor;

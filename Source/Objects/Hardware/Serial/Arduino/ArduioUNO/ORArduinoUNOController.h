//--------------------------------------------------------
// ORArduinoUNOController
// Created by Mark  A. Howe on Wed 10/17/2012
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2012 University of North Carolina. All rights reserved.
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

@class ORSerialPortController;

@interface ORArduinoUNOController : OrcaObjectController
{
    IBOutlet NSButton*		lockButton;
	IBOutlet NSButton*		updateButton;
    IBOutlet NSPopUpButton* pollTimePopup;
	IBOutlet NSMatrix*		adcMatrix;
	IBOutlet NSMatrix*		pinTypeMatrix;
	IBOutlet NSMatrix*		pinNameMatrix;
	IBOutlet NSMatrix*		pinValueOutMatrix;
	IBOutlet NSMatrix*		pinValueInMatrix;
	IBOutlet NSMatrix*		pwmMatrix;
    IBOutlet ORSerialPortController* serialPortController;
}

#pragma mark •••Initialization
- (id) init;
- (void) dealloc;
- (void) awakeFromNib;

#pragma mark •••Notifications
- (void) registerNotificationObservers;
- (void) updateWindow;
- (void) updateButtons;
- (void) lockChanged:(NSNotification*)aNote;
- (void) adcChanged:(NSNotification*)aNote;
- (void) pinNameChanged:(NSNotification*)aNote;
- (void) pinTypeChanged:(NSNotification*)aNote;
- (void) pinValueInChanged:(NSNotification*)aNote;
- (void) pinValueOutChanged:(NSNotification*)aNote;
- (void) pwmChanged:(NSNotification*)aNote;

#pragma mark •••Interface Management
- (void) pollTimeChanged:(NSNotification*)aNote;
- (BOOL) portLocked;

#pragma mark •••Actions
- (IBAction) pollTimeAction:(id)sender;
- (IBAction) lockAction:(id) sender;
- (IBAction) updateAllAction:(id)sender;
- (IBAction) pollTimeAction:(id)sender;
- (IBAction) pwmAction:(id)sender;
- (IBAction) pinTypeAction:(id)sender;
- (IBAction) pinNameAction:(id)sender;
- (IBAction) pinValueOutAction:(id)sender;
- (IBAction) writeValues:(id)sender;
@end


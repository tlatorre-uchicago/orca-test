                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                for (i=0; i<numberBins; ++i) {
        fprintf(aFile, "%ld\n",histogram[i]);
    }
    fprintf(aFile, "END\n\n");
}


- (int)	numberOfPointsInPlot:(id)aPlotter dataSet:(int)set
{
    return numberBins;
}

- (float) plotter:(id) aPlotter dataSet:(int)set dataValue:(int) x 
{
    return [self value:x];
}

- (void) setDataIds:(id)assigner
{
    dataId       = [assigner assignDataIds:kLongForm];
}

- (void) syncDataIdsWith:(id)anotherCard
{
    [self setDataId:[anotherCard dataId]];
}

- (NSDictionary*) dataRecordDescription
{
    NSMutableDictionary* dataDictionary = [NSMutableDictionary dictionary];
    NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"OR1DHistoDecoder",                        @"decoder",
        [NSNumber numberWithLong:dataId],           @"dataId",
        [NSNumber numberWithBool:YES],              @"variable",
        [NSNumber numberWithLong:-1],               @"length",
        nil];
    [dataDictionary setObject:aDictionary forKey:@"Histograms"];
    return dataDictionary;
}

- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(id)userInfo
{
    //----------------------------------------------------------------------------------------
    // first add our description to the data description
    [aDataPacket addDataDescriptionItem:[self dataRecordDescription] forKey:@"1DHisto"];

}

#pragma mark ���Data Source Methods

- (id)   name
{
    return [NSString stringWithFormat:@"%@ 1D Histogram Events: %d",[self key], [self totalCounts]];
}


- (void) histogram:(unsigned long)aValue
{
    if(!histogram){
        [self setNumberBins:4096];
    }
    if(aValue>=numberBins)++overFlow;
    else {
        ++histogram[aValue];
        [self incrementTotalCounts];
    }
}


- (void) packageData:(ORDataPacket*)aDataPacket userInfo:(id)userInfo keys:(NSMutableArray*)aKeyArray
{
    NSMutableData* dataToShip = [NSMutableData data];
    unsigned long dataWord;
    
    //first the id
    dataWord = dataId; //note we don't know the length yet--we'll fill it in later
    [dataToShip appendBytes:&dataWord length:4];

    //append the keys
    unsigned long numKeys = [aKeyArray count];
    [dataToShip appendBytes:&numKeys length:4];
    NSEnumerator* e = [aKeyArray objectEnumerator];
    id aKey;
    while(aKey = [e nextObject]){
        const char *p = [aKey cString];
        unsigned long len = (strlen(p)+1; //include the '\0' at end of cString
        len = [len+4)/4; //align to long boundary
        [dataToShip appendBytes:&len length:4];
        [dataToShip appendBytes:p length:len];
    }
    
    [dataToShip appendBytes:&numberBins length:4];            //length of the histogram
    [dataToShip appendBytes:histogram length:numberBins*4]; //note size in number bytes--not longs
    
    //go back and fill in the total length
    unsigned long *ptr = (unsigned long*)[dataToShip bytes];
    unsigned long totalLength = [dataToShip length]/4;
    *ptr |= 0x0003ffff&totalLength; //note size in number longs
    [aDataPacket addData:dataToShip];
}

#pragma  mark ���Actions
- (void) makeMainController
{
    [self linkToController:@"OR1DHistoController"];
}

#pragma mark ���Archival
static NSString *OR1DHistoNumberBins	= @"1D Histogram Number Bins";

- (id)initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    [[self undoManager] disableUndoRegistration];
    
    [self setNumberBins:[decoder decodeIntForKey:OR1DHistoNumberBins]];
    
    [[self undoManager] enableUndoRegistration];
    return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeInt:numberBins forKey:OR1DHistoNumberBins];
}


@end

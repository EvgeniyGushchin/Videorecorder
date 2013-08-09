//
//  VideoRecorder.m
//  videorecord
//
//  Created by Evgeniy Gushchin on 7/19/13.
//  Copyright (c) 2013 Evgeniy Gushchin. All rights reserved.
//

#import "VideoRecorder.h"
#import "UIImage+Extras.h"
#import "VideoFrameData.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import "ALAssetsLibrary+CustomPhotoAlbum.h"

#define TIME_SCALE 44100

enum {
    WDASSETURL_PENDINGREADS = 1,
    WDASSETURL_ALLFINISHED = 0
};

@interface VideoRecorder () {
    NSInteger numberOfChunks;
    NSConditionLock* assetReadLock;
    BOOL isExporting;
    RecordCompletionBlock completionBlock;
    NSInteger totalFrameCounter;
}

@end

@implementation VideoRecorder {
    NSArray *framesArray;
    ALAssetsLibrary *assetsLibrary;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    AVAssetWriter *videoWriter;
    AVMutableComposition *mixComposition;
}
@synthesize hdQuality, watermarkImage, videoTitle;

- (id)initWithFrames:(NSArray *)frames andLibrary:(ALAssetsLibrary *)library {
    self = [super init];
    if (self) {
        framesArray = frames;
        assetsLibrary = library;
        totalFrameCounter = 0;
    }
    return self;
}

#pragma mark - File System Directories

- (NSString *)documentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
}

- (NSString *)videoDirectory {
    return [[self documentsDirectory] stringByAppendingFormat:@"/videos"];
}

- (void)cleanDocumentsTemp
{
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"videos-chunk_*+"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    
    //delete temporary video file if it exist
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self documentsDirectory]
                                                                               error:&error];
    for (NSString *tString in dirContents)
    {
        if ([tString isEqualToString:@"videos.mp4"])
        {
            [[NSFileManager defaultManager]removeItemAtPath:[NSString stringWithFormat:@"%@/%@",
                                                             [self documentsDirectory],
                                                             tString]
                                                      error:nil];
        }
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:tString
                                                            options:0
                                                              range:NSMakeRange(0, [tString length])];
        if (numberOfMatches > 0)
        {
            [[NSFileManager defaultManager]removeItemAtPath:[NSString stringWithFormat:@"%@/%@",
                                                             [self documentsDirectory],
                                                             tString]
                                                      error:nil];
        }
    }
}

#pragma mark - Setup

- (void)createVideoWriterforPath:(NSString *)path andSize:(CGSize)size {
    //create asset writer
    NSError *error;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                            fileType:AVFileTypeAppleM4V
                                               error:&error];
    [self setupWriterInputwithFrameSize:size];
}

- (void)setupWriterInputwithFrameSize:(CGSize)size {
    NSParameterAssert(videoWriter);
    //create video input
    NSNumber *videoWidth  = [NSNumber numberWithInt:size.width];
    NSNumber *videoHeight = [NSNumber numberWithInt:size.height];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   videoWidth, AVVideoWidthKey,
                                   videoHeight, AVVideoHeightKey,
                                   nil];
    AVAssetWriterInput * writerInput = [[AVAssetWriterInput   alloc] initWithMediaType:AVMediaTypeVideo
                                                                        outputSettings:videoSettings];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    [videoWriter addInput:writerInput];
}

- (void)createVideoAdaptorForSize:(CGSize)size {
    if (!videoWriter) {
        return;
    }
    //create adaptor
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    [attributes setObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    [attributes setObject:[NSNumber numberWithInt:size.width] forKey:(NSString*)kCVPixelBufferWidthKey];
    [attributes setObject:[NSNumber numberWithInt:size.height] forKey:(NSString*)kCVPixelBufferHeightKey];
    adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:[videoWriter.inputs objectAtIndex:0]
                                                         sourcePixelBufferAttributes:attributes];
}

#pragma mark - Video Work

- (void)recordVideowithcmpletionBlock:(RecordCompletionBlock)_completionBlock
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        completionBlock = _completionBlock;
        [self cleanDocumentsTemp];
        CGSize videoSize = CGSizeMake(640, 480);
        if (hdQuality) {
            videoSize = CGSizeMake(1280, 720);
        }
        [self writeImagesToMovieAtPath:[self videoDirectory] withSize:videoSize];
        [self mergeVideoAtPath:[self videoDirectory]];
        
        NSLog(@"Write Ended");
    });
}

-(void) writeImagesToMovieAtPath:(NSString *) path withSize:(CGSize) size
{
    NSLog(@"Write Started");
    
    //Disable idle timer for record
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    //to reduce memory usage during video recording we are spliting array of frames on small chunks by 4 frames
    NSInteger chunksBySession = 4;
    NSInteger chunks = [framesArray count] / chunksBySession;
    NSInteger tail = [framesArray count] % chunksBySession;
    
    numberOfChunks = chunks;
    
    for (int i = 0; i < chunks; i++) {
        NSRange range = NSMakeRange(i * chunksBySession, (i + 1) * chunksBySession);
        [self writeImagesToMovieAtPath:[path stringByAppendingFormat:@"-chunk_%d.mp4", i] withSize:size withRange:range];
    }
    
    if (tail != 0) {
        NSRange range = NSMakeRange(chunks * chunksBySession, chunks * chunksBySession + tail);
        [self writeImagesToMovieAtPath:[path stringByAppendingFormat:@"-chunk_%d.mp4", chunks] withSize:size withRange:range];
        numberOfChunks++;
    }
}

- (void)writeImagesToMovieAtPath:(NSString *)path withSize:(CGSize)size withRange:(NSRange)range
{
    @autoreleasepool {
        
        [self createVideoWriterforPath:path andSize:size];
        [self createVideoAdaptorForSize:size];
        
        //Start a session:
        [videoWriter startWriting];
        [videoWriter startSessionAtSourceTime:(CMTimeMake(0, TIME_SCALE))];
        
        CVPixelBufferRef buffer = NULL;
        int frameCount = range.location;
        CMTime durationTime = kCMTimeZero;
        
        VideoFrameData *firstFrameInThisChunk = [framesArray objectAtIndex:range.location];
        CMTime videoShiftForThisChunk = firstFrameInThisChunk.presentationTime;
        CMTime previousFrameTime = CMTimeSubtract(kCMTimeZero, videoShiftForThisChunk);
        if ([framesArray count] > range.length) {
            VideoFrameData *additionalFrameData = [framesArray objectAtIndex:range.length];
            durationTime = CMTimeSubtract(additionalFrameData.presentationTime,CMTimeMake(1, TIME_SCALE));
        }
        
        for (int i = range.location; i < range.length; i++)
        {
            [self updateProgressForFrames];
            VideoFrameData *frameData = [framesArray objectAtIndex:i];
            
            CMTime frameTime = CMTimeAdd(frameData.presentationTime, previousFrameTime);
            NSLog(@"frame time value %lld \n scale: %d\n",frameTime.value/frameTime.timescale,frameTime.timescale);
            
            UIImage * frameImage = [self imageForProcessFromFrameData:frameData withSize:size];
            
            buffer = [self pixelBufferFromCGImage:[frameImage CGImage] andSize:size];
            if (frameCount == [framesArray count]-1)
            {
                NSInteger dif = frameTime.value - previousFrameTime.value;
                NSInteger addFramesCount = dif/TIME_SCALE;
                if (addFramesCount > 5) {
                    addFramesCount = 5;
                }
                for (int j = addFramesCount; j > 0; j--)
                {
                    int64_t t_value = frameTime.value - (TIME_SCALE)*(j);
                    if (t_value >= frameTime.value)
                    {
                        t_value = frameTime.value - 1;
                    }
                    if (t_value == previousFrameTime.value) {
                        t_value = previousFrameTime.value + 1;
                    }
                    CMTime additionalTime = CMTimeMake(t_value, frameTime.timescale);
                    [self addBufer:buffer toAdaptor:adaptor toWriter:videoWriter withTime:additionalTime frameCount:frameCount];
                }
            }
            
            [self addBufer:buffer toAdaptor:adaptor toWriter:videoWriter withTime:frameTime frameCount:frameCount];
            if(buffer)
                CVBufferRelease(buffer);
            previousFrameTime = frameTime;
            
            frameCount++;
            totalFrameCounter++;
        }
        
        //Finish the session:
        if (durationTime.value > 0) {
            durationTime = CMTimeAdd(previousFrameTime, durationTime);

            VideoFrameData *frameData = [framesArray objectAtIndex:range.length];
            UIImage * frameImage = [self imageForProcessFromFrameData:frameData withSize:size];
            buffer = [self pixelBufferFromCGImage:[frameImage CGImage] andSize:size];
            [self addBufer:buffer toAdaptor:adaptor toWriter:videoWriter withTime:durationTime frameCount:frameCount];
            if(buffer)CVBufferRelease(buffer);
            previousFrameTime = durationTime;
        }
        
        [videoWriter endSessionAtSourceTime:previousFrameTime];
        __block BOOL isFinished = NO;
        [videoWriter finishWritingWithCompletionHandler:^{
            isFinished = YES;
            NSLog(@"finished writing");
        }];
        while (videoWriter.status != AVAssetWriterStatusCompleted) {
            NSLog(@"whait while writer winishing file. status %d",videoWriter.status);
        }
    }
}

-(void)addBufer:(CVPixelBufferRef)buffer
      toAdaptor:(AVAssetWriterInputPixelBufferAdaptor *)bufferAdaptor
       toWriter:(AVAssetWriter *)_videoWriter
       withTime:(CMTime)frameTime
     frameCount:(NSInteger)frameCount
{
    BOOL append_ok = NO;
    int j = 0;
    while (!append_ok && j < 30)
    {
        if (bufferAdaptor.assetWriterInput.readyForMoreMediaData)
        {
            NSLog(@"appending %d attemp %d  time: %lld \n", frameCount, j, frameTime.value/frameTime.timescale);
            append_ok = [bufferAdaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
            
            [NSThread sleepForTimeInterval:0.05];
            NSLog(@"Error: %@\n", _videoWriter.error);
        }
        else
        {
            NSLog(@"adaptor not ready %d, %d\n", frameCount, j);
            [NSThread sleepForTimeInterval:0.2];
        }
        j++;
    }
    if (!append_ok)
    {
        NSLog(@"error appending image %d times %d\n", frameCount, j);
        NSLog(@"Error: %@\n", _videoWriter.error);
    }
}


- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image andSize:(CGSize) size
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width,
                                          size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width,
                                                 size.height, 8, 4*size.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

#pragma mark - Image Processing

- (UIImage *)imageForProcessFromFrameData:(VideoFrameData *)frameData withSize:(CGSize)size{
    
    UIImage *imageFromFrame = [self imageFromFrameData:frameData];
    // resize image to proper size
    UIImage *resizedImage = [imageFromFrame imageByScalingProportionallyToSize:size];
    // add watermark to image
    UIImage * markedImage = [self addWatermarkToImage:resizedImage];
    
    NSData *imgData = UIImageJPEGRepresentation(markedImage, 1); // 1 is compression quality
    
    // Identify the home directory and file name
    NSString  *jpgPath = [[self documentsDirectory] stringByAppendingPathComponent:@"/Test.jpg"];
    [imgData writeToFile:jpgPath atomically:YES];
    
    NSData *imgData2 = UIImageJPEGRepresentation(resizedImage, 1); // 1 is compression quality
    
    // Identify the home directory and file name
    NSString  *jpgPath2 = [[self documentsDirectory] stringByAppendingPathComponent:@"/Test2.jpg"];
    [imgData2 writeToFile:jpgPath2 atomically:YES];
    return markedImage;
}

- (UIImage *)imageFromFrameData:(VideoFrameData *)frameData {
    
    if (frameData.img) return frameData.img;
    
    if (frameData.imageLink) return [UIImage imageWithContentsOfFile:frameData.imageLink];
    
    if (frameData.libraryAssetURL) return [self getImageFromLibraryWithURL:frameData.libraryAssetURL];
    
    NSLog(@"can't get image from VideoFrameData");
    return nil;
}

- (UIImage *)getImageFromLibraryWithURL:(NSURL *)assetUrl {
    //use lock because read from library is a async process
    
    if (!assetsLibrary) {
        assetsLibrary = [ALAssetsLibrary new];
    }
    
    //lock execution
    NSAssert(![NSThread isMainThread], @"can't be called on the main thread due to ALAssetLibrary limitations");
    assetReadLock = [[NSConditionLock alloc] initWithCondition:WDASSETURL_PENDINGREADS];
    __block UIImage *img;
    [assetsLibrary assetForURL:assetUrl
                   resultBlock:^(ALAsset *asset) {
                       img = [UIImage imageWithCGImage:[[asset defaultRepresentation] fullResolutionImage]
                                                 scale:[asset defaultRepresentation].scale
                                           orientation:[[asset valueForProperty:ALAssetPropertyOrientation]integerValue]];
                       [assetReadLock lock];
                       [assetReadLock unlockWithCondition:WDASSETURL_ALLFINISHED];
                   }
                  failureBlock:^(NSError *error) {
                      NSLog(@"fail to get image");
                      [assetReadLock lock];
                      [assetReadLock unlockWithCondition:WDASSETURL_ALLFINISHED];
                  }];
    [assetReadLock lockWhenCondition:WDASSETURL_ALLFINISHED];
    [assetReadLock unlock];
    
    // cleanup
    assetReadLock = nil;
    return img;
}

-(UIImage*)addWatermarkToImage:(UIImage*)img {
    UIImage *markedImg = img;
    if(watermarkImage) {
        UIGraphicsBeginImageContext(img.size);
        [img drawInRect:(CGRectMake(0, 0, img.size.width, img.size.height))];
        [watermarkImage drawInRect:(CGRectMake(img.size.width - (watermarkImage.size.width + 5),
                                               img.size.height - (watermarkImage.size.height + 5),
                                               watermarkImage.size.width,
                                               watermarkImage.size.height))];
        markedImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return markedImg;
}

#pragma mark - Merge Video

-(void)mergeVideoAtPath:(NSString *)path
{
    if ([self createCompositionFromPath:path]) {
        [self exportAsset];
    }
}

- (BOOL)createCompositionFromPath:(NSString *)path {
    mixComposition = [AVMutableComposition composition];
    
    CMTime durationAccumulator = kCMTimeZero;
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    for (int i = 0; i < numberOfChunks; i++) {
        NSString *videoPathString = [path stringByAppendingFormat:@"-chunk_%d.mp4", i];
        NSURL *moviePath = [NSURL fileURLWithPath:videoPathString];
        
        AVURLAsset *currentVideoAsset = [[AVURLAsset alloc] initWithURL:moviePath options:nil];
        
        if ([[currentVideoAsset tracksWithMediaType:AVMediaTypeVideo] count] == 0) {
            NSLog(@"No video found");
            NSString *msgString =  NSLocalizedString(@"No video found! Please try again.", @"No video found! Please try again.");
            if (completionBlock) {
                NSError *error = [NSError errorWithDomain:NSMachErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: msgString}];
                completionBlock(NO,error);
            }
            return NO;
        }
        
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, currentVideoAsset.duration)
                                       ofTrack:[[currentVideoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                        atTime:durationAccumulator
                                         error:nil];
        durationAccumulator = CMTimeAdd(durationAccumulator, currentVideoAsset.duration);
    }
    return YES;
}

- (void)checkVideoDirectory {
    BOOL isDir = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self videoDirectory]
                                              isDirectory:&isDir] && isDir)
    {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:[self videoDirectory]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    };
}

- (NSString *)exportPath {
    NSString* videoName = [NSString stringWithFormat:@"/%@.mp4",videoTitle];
    NSString *exportPath = [[self videoDirectory] stringByAppendingPathComponent:videoName];
    
    int i = 0;
    while ([[NSFileManager defaultManager] fileExistsAtPath:exportPath]) {
        videoName = [NSString stringWithFormat:@"/%@_%d.mp4",videoTitle,i];
        exportPath = [[self videoDirectory] stringByAppendingPathComponent:videoName];
        i++;
    }
    return exportPath;
}

- (void) updateMetadataForExportSession:(AVAssetExportSession *)exportSession {
    NSArray *existingMetadataArray = exportSession.metadata;
    NSMutableArray *newMetadataArray = nil;
    if (existingMetadataArray) {
        newMetadataArray = [existingMetadataArray mutableCopy];
    }
    else {
        newMetadataArray = [[NSMutableArray alloc] init];
    }
    
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.keySpace = AVMetadataKeySpaceCommon;
    item.key = AVMetadataCommonKeyTitle;
    item.locale = [NSLocale currentLocale];
    item.value = [NSString stringWithFormat:@"%@",self.videoTitle];
    
    AVMutableMetadataItem *item2 = [[AVMutableMetadataItem alloc] init];
    item2.keySpace = AVMetadataKeySpaceCommon;
    item2.key = AVMetadataCommonKeyCreationDate;
    item2.value = [NSDate date];
    
    [newMetadataArray addObject:item];
    [newMetadataArray addObject:item2];
    
    exportSession.metadata = newMetadataArray;
}

- (void)exportAsset {
    // check export directory
    [self checkVideoDirectory];
    
    //set export URL
    NSURL *exportUrl = [NSURL fileURLWithPath:[self exportPath]];
    
    AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                         presetName:AVAssetExportPresetHighestQuality];
    assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    assetExport.outputURL = exportUrl;
    
    [self updateMetadataForExportSession:assetExport];
    isExporting = YES;
    [assetExport exportAsynchronouslyWithCompletionHandler:
     ^(void ) {
         switch (assetExport.status)
         {
             case AVAssetExportSessionStatusFailed:
             {
                 isExporting = NO;
                 NSString *message = NSLocalizedString(@"Fail to create video", @"Fail to create video");
                 if (completionBlock) {
                     NSError *error = [NSError errorWithDomain:NSMachErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: message}];
                     completionBlock(NO,error);
                 }
             }
                 break;
             case AVAssetExportSessionStatusCompleted:
             {
                 isExporting = NO;
                 NSLog (@"SUCCESS");
                 if (_albumName) {
                     [self saveVideoToAlbum:assetExport.outputURL];
                 }
                 else {
                     if (completionBlock) {
                         completionBlock(YES,nil);
                     }
                 }
                 
             }
                 break;
         };
     }];
    while(isExporting){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateSavingProgressForExportSession:assetExport];
        });
        [NSThread sleepForTimeInterval:1.0];;
    }
}

- (void)saveVideoToAlbum:(NSURL *)videoUrl {
    if (!assetsLibrary) {
        assetsLibrary = [ALAssetsLibrary new];
    }
    [assetsLibrary saveVideoAPath:videoUrl
                          toAlbum:_albumName
                  withResultBlock:^(NSURL * assetUrl, NSError *error)
     {
         if (error != nil)
         {
             if(error.code == 1000)
             {
                 //TODO: fix and remove!!! try again (bug with creation album in first time)
                 [assetsLibrary saveVideoAPath:videoUrl
                                       toAlbum:_albumName
                               withResultBlock:^(NSURL * assetUrl, NSError *error)
                  {
                      [self completeRecordWithResult:YES andError:error];
                  }
                                  failureBlock:^(NSError *error)
                  {
                      if (error)
                      {
                          NSLog(@"error: %@",error);
                          [self completeRecordWithResult:YES andError:error];
                      }
                  }];
             }else
             {
                 NSLog(@"error: %@",error);
                 [self completeRecordWithResult:YES andError:error];
             }
             
         }
         [self completeRecordWithResult:YES andError:nil];
     }
                     failureBlock:^(NSError *error)
     {
         NSLog(@"error: %@",error);
         [self completeRecordWithResult:YES andError:error];
     }];
}

- (void)completeRecordWithResult:(BOOL)result andError:(NSError *)error {
    if (completionBlock) {
        completionBlock(result,error);
    }
}

#pragma mark - Record progress

- (void)updateProgressForFrames {
     NSString *progressStr = [NSString stringWithFormat:NSLocalizedString(@"Generating frame %d",@"Generating frame %d"),totalFrameCounter];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate updateProgressWithMessage:progressStr];
    });
}
- (void)updateSavingProgressForExportSession:(AVAssetExportSession *)exportSession {
    float pr = exportSession.progress;
    int progress =  (int)(pr * 100);
    NSString *progressStr = [NSString stringWithFormat:NSLocalizedString(@"Saving Video %d%%",@"Saving Video %d%%"),progress];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate updateProgressWithMessage:progressStr];
    });
}
@end

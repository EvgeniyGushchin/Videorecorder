//
//  ViewController.m
//  videorecord
//
//  Created by Evgeniy Gushchin on 7/19/13.
//  Copyright (c) 2013 Evgeniy Gushchin. All rights reserved.
//

#import "ViewController.h"

#import "VideoFrameData.h"
#import <AssetsLibrary/AssetsLibrary.h>


@implementation ViewController {
    NSMutableArray *frameArray;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    frameArray = [NSMutableArray array];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSArray *)framesArray {
    VideoFrameData *frame1 = [VideoFrameData new];
    frame1.img = [UIImage imageNamed:@"img1.jpeg"];
    frame1.presentationTime = CMTimeMake(0, 1);
    
    VideoFrameData *frame2 = [VideoFrameData new];
    frame2.img = [UIImage imageNamed:@"img2.jpeg"];
    frame2.presentationTime = CMTimeMake(3, 1);
    
    VideoFrameData *frame3 = [VideoFrameData new];
    frame3.img = [UIImage imageNamed:@"img3.jpeg"];
    frame3.presentationTime = CMTimeMake(3, 1);
    
    // add last image again to get shure that last frame will last for a specified time
    VideoFrameData *frame4 = [VideoFrameData new];
    frame4.img = [UIImage imageNamed:@"img3.jpeg"];
    frame4.presentationTime = CMTimeMake(3, 1);

    return @[frame1,frame2,frame3,frame4];
}

- (IBAction)record:(id)sender {
    VideoRecorder *recorder = [[VideoRecorder alloc]initWithFrames:frameArray andLibrary:nil];
    recorder.videoTitle = @"FirstTest";
    recorder.delegate = self;
    [recorder recordVideowithcmpletionBlock:^(BOOL succsess, NSError *error) {
        NSLog(@"succsess %d\nerror %@",succsess,error);
    }];
}

- (IBAction)addButton:(id)sender {
    ALAssetsLibrary *assetsLibrary = [ALAssetsLibrary new];
    
    [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop)
         {
             if (!result && (index == NSNotFound))
             {
                 *stop = YES;
             }
             else {
                 NSDictionary *buf = [result valueForProperty:ALAssetPropertyURLs];
                 NSArray *urls = [buf allValues];
                 if (urls)
                 {
                     VideoFrameData *frame = [VideoFrameData new];
                     frame.libraryAssetURL = [urls lastObject];
                     if (frameArray.count == 0) {
                         frame.presentationTime = CMTimeMake(0, 1);
                     }
                     else {
                         frame.presentationTime = CMTimeMake(3, 1);
                     }
                     [frameArray addObject:frame];
                 }
             }
         }];
        [frameArray addObject:[frameArray lastObject]];
    } failureBlock:^(NSError *error) {
        NSLog(@"MainViewController error:%@", error.description);
    }];

}

- (void)updateProgressWithMessage:(NSString *)progressMsg {
    _progressLabel.text = progressMsg;
}

- (void)viewDidUnload {
    [self setProgressLabel:nil];
    [super viewDidUnload];
}

#pragma mark - PickerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
}
@end

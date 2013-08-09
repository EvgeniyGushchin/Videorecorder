//
//  ViewController.h
//  videorecord
//
//  Created by Evgeniy Gushchin on 7/19/13.
//  Copyright (c) 2013 Evgeniy Gushchin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoRecorder.h"

@interface ViewController : UIViewController<VideoRecorderProtocol>
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
- (IBAction)record:(id)sender;
- (IBAction)addButton:(id)sender;

@end

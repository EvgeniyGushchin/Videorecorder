Videorecorder
=============

Videorecorder makes video from your images.

Next frameworks are necessary for Videorecorder work:
- AVFoundation;
- AssetsLibrary.

Videorecorder uses next categories:
- ALAssetsLibrary+CustomPhotoAlbum;
- UIImage+Extras.

All categories ccan be found in the project dir.

Example of use Videorecorder:

VideoRecorder *recorder = [[VideoRecorder alloc]initWithFrames:frameArray andLibrary:nil];
    recorder.videoTitle = @"FirstTest";
    recorder.delegate = self;
    [recorder recordVideowithcmpletionBlock:^(BOOL succsess, NSError *error) {
        NSLog(@"succsess %d\nerror %@",succsess,error);
    }];

frameArray  - it is an array of VideoFrameData objects.

VideoFrameData - it is an object, that contains information about video frame;

- presentationTime - it is a CMTime at which frame should appear at video;

Example: 
presentationTime = CMTimeMake(0, 1); - frame will be presented at start
presentationTime = CMTimeMake(3, 1); - frame will be presented after three seconds of a previous frame;

If we have three frames with times (0, 1), (3, 1) and (5, 1), then first frame will be presented at start,
second will be presented at 3 second and third will be presented at 8 second (0 + 3 + 5). Total duration
of videofile will be 5 seconds (last frame will has duration == 0). If you want to set not null duration for 
last frame, then you should add addtional last frame with same image and time which will be equal to duration time.

- img  - UIImage;
- libraryAssetURL - url of image in ALAssetsLibrary
- imageLink - link on image eg. in Documents; 

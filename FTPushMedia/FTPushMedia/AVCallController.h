//
//  AVCallController.h
//  Pxlinstall
//
//  Created by Lin Charlie C. on 11-3-24.
//  Copyright 2011  xxxx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#include "libavutil/pixdesc.h"
#include "libavutil/opt.h"
#include "libavformat/internal.h"
#include "libavutil/internal.h"
#include "libavutil/time.h"
#import "libswscale/swscale.h"
typedef struct
{
    AVClass*        class;
    
    float           frame_rate;
    int             frames_captured;
    int64_t         first_pts;
    pthread_mutex_t frame_lock;
    pthread_cond_t  frame_wait_cond;
    id              avf_delegate;
    
    int             list_devices;
    int             video_device_index;
    enum AVPixelFormat pixel_format;
    
    AVCaptureSession         *capture_session;
    AVCaptureVideoDataOutput *video_output;
    CMSampleBufferRef         current_frame;
} AVFContext;

@interface AVCallController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>
{
	//UI
	UILabel *labelState;
	UIButton *btnStartVideo;
	UIView  *localView;
	
	AVCaptureSession* avCaptureSession;
	AVCaptureDevice *avCaptureDevice;
	BOOL firstFrame;	//是否为第一帧
	int producerFps;

}
@property (assign, nonatomic) IBOutlet UIImageView *imageVIew;
@property (assign, nonatomic) IBOutlet UIImageView *imageView2;
@property (nonatomic, retain) AVCaptureSession *avCaptureSession;
@property (nonatomic, retain) UILabel *labelState;

- (void)createControl;
- (AVCaptureDevice *)getFrontCamera;
- (void)startVideoCapture;
- (void)stopVideoCapture:(id)arg;
@end

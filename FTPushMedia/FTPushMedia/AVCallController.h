//
//  AVCallController.h
//  Pxlinstall
//
//  Created by Lin Charlie C. on 11-3-24.
//  Copyright 2011  xxxx. All rights reserved.
//
/**
 https://youtu.be/TqvepHLdZyM 1
 https://youtu.be/4ptQ6ZI2VHA 1
 https://youtu.be/yj46EbUXRhE 1
 https://youtu.be/zeMjRt-3fKc 1
 https://youtu.be/6JLe5Z6xFlY 1
 https://youtu.be/zfGlczwHXaE 1
 https://youtu.be/oROyz1V6b10 1
 https://youtu.be/s53rFohEJHo 1
 https://youtu.be/RdtjqaK2Gew
 https://youtu.be/mQXTaYhkpEc 1
 https://youtu.be/bRd_xufmZOQ 1
 https://youtu.be/Pob1lbKr9FQ 1
 https://youtu.be/ijuMpgWVTo0 1
 https://youtu.be/8F0b51rmacs
 **/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#include "libavutil/pixdesc.h"
#include "libavutil/opt.h"
#include "libavutil/time.h"
#import "libswscale/swscale.h"
#include "libavformat/internal.h"

#import <AudioToolbox/AudioToolbox.h>

#define QUEUE_BUFFER_SIZE 4 //队列缓冲个数
#define EVERY_READ_LENGTH 1000 //每次从文件读取的长度
#define MIN_SIZE_PER_FRAME  1024 * 4//3000 //每侦最小数据长度

typedef struct
{
    AVClass*        class;
    
    int             frames_captured;
    int             audio_frames_captured;
    int64_t         first_pts;
    int64_t         first_audio_pts;
    pthread_mutex_t frame_lock;
    pthread_cond_t  frame_wait_cond;
    id              avf_delegate;
    id              avf_audio_delegate;
    
    int             list_devices;
    int             video_device_index;
    int             video_stream_index;
    int             audio_device_index;
    int             audio_stream_index;
    
    char            *video_filename;
    char            *audio_filename;
    
    int             num_video_devices;
    
    int             audio_channels;
    int             audio_bits_per_sample;
    int             audio_float;
    int             audio_be;
    int             audio_signed_integer;
    int             audio_packed;
    int             audio_non_interleaved;
    
    int32_t         *audio_buffer;
    int             audio_buffer_size;
    
    enum AVPixelFormat pixel_format;
    
    AVCaptureSession         *capture_session;
    AVCaptureVideoDataOutput *video_output;
    AVCaptureAudioDataOutput *audio_output;
    CMSampleBufferRef         current_frame;
    CMSampleBufferRef         current_audio_frame;
    
    //done by zws
    AVCodecContext *audioContext;
    AVCodecContext *videoContext;
    struct SwrContext* swrCtx;
} AVFContext;

@interface AVCallController : UIViewController 
{
        AudioStreamBasicDescription audioDescription;///音频参数
        AudioQueueRef audioQueue;//音频播放队列
        AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];//音频缓存
        NSLock *synlock ;///同步控制
        Byte *pcmDataBuffer;//pcm的读文件数据区
        FILE *file;//pcm源文件
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

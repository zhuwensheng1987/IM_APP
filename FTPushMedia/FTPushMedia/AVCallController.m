//
//  AVCallController.m
//  Pxlinstall
//
//  Created by Lin Charlie C. on 11-3-24.
//  Copyright 2011  高鸿移通. All rights reserved.
//

#import "AVCallController.h"
#import "VideoFrameExtractor.h"
#include "libavformat/avformat.h"
#include "libavutil/mathematics.h"
#include "libavutil/time.h"
#import "libswresample/swresample.h"
#import "Utilities.h"
#import "UIAlertView+Block.h"

//#import "FFLocalFileManager.h"
//#import "FFSparkViewController.h"
//#import "FFAlertView.h"
#import "FFPlayer.h"
#import "FFPlayHistoryManager.h"
void audio_encode_example(const char *filename);
void audio_decode_example(const char *outfilename, const char *filename);
AVCallController *ttt;
UIImage* CVImageBufferRef2UIImage(CVImageBufferRef imageBuffer);
CVPixelBufferRef pixelBufferFromCGImage(CGImageRef image);
struct AVFPixelFormatSpec {
    enum AVPixelFormat ff_id;
    OSType avf_id;
};
@interface AVCallController (){
    FFPlayer *  _player;
    CMSampleBufferRef         current_audio_frame;
    float lastFrameTime;
    uint8_t* frame_buf;
}
@property (nonatomic, strong)NSTimer *paintingTimer;
- (IBAction)outAction:(id)sender;
@property (assign, nonatomic) IBOutlet UITextField *inputUsrlTextField;
- (IBAction)checkInputAction:(id)sender;
- (IBAction)palyInputAction:(id)sender;

@property (assign, nonatomic) IBOutlet UITextField *outUrlTextField;
@property (nonatomic, strong)VideoFrameExtractor *video;

- (AVCodecContext *)context:(int)w h:(int)h;
@end




@implementation AVCallController

@synthesize avCaptureSession;
@synthesize labelState;

-(id)init
{
    if(self = [super init])
    {
        firstFrame = YES;
        producerFps = 50;
    }
    return self;
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    [super loadView];
    ttt = self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    _player = [[FFPlayer alloc] init];
    
    synlock = [[NSLock alloc] init];
    // av_samples_get_buffer_size(NULL, context->channels,context->frame_size,context->sample_fmt, 1);
    //
    frame_buf = av_mallocz(MIN_SIZE_PER_FRAME);
    
    // video images are landscape, so rotate image view 90 degrees
    [_imageVIew setTransform:CGAffineTransformMakeRotation(M_PI/2)];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

extern AVInputFormat ff_avfoundation_demuxer_zws;

- (void)localPalyer{
    
    NSString *inputUrl = self.inputUsrlTextField.text;
    if ([inputUrl isEqualToString:@""] || !inputUrl) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"请输入" delegate:nil cancelButtonTitle:@"确认" otherButtonTitles:nil,nil];
        [alert showAlertViewWithCompleteBlock:^(NSInteger buttonIndex) {
        }];
    }
    self.video = [[VideoFrameExtractor alloc] initWithVideo:inputUrl];
    //    self.video = [[VideoFrameExtractor alloc] initWithVideo:@"rtmp://172.18.1.203/live/t3"];
    
    
    NSLog(@"video duration: %f",_video.duration);
    NSLog(@"video size: %d x %d", _video.sourceWidth, _video.sourceHeight);
}

#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)


-(NSInteger)readRunning{
    while ([_video getPacket]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _imageVIew.image = _video.currentImage;
        });
    }
    frame_buf = _video.frame_buf;
    return _video.count;
}

- (void)dellocExtradata:(AVCodecContext*)pCodecCtx{
    realloc(pCodecCtx->extradata, 32);
}

- (void)allocExtradata:(AVCodecContext*)pCodecCtx{
    
    pCodecCtx->extradata = malloc(5); //new uint8_t[32];//给extradata成员参数分配内存
    pCodecCtx->extradata_size = 5;//extradata成员参数分配内存大小
  
    //    //给extradata成员参数设置值
    //    //12 08 56 E5 00
    pCodecCtx->extradata[0] = 0x12;
    pCodecCtx->extradata[1] = 0x08;
    pCodecCtx->extradata[2] = 0x56;
    pCodecCtx->extradata[3] = 0xE5;
    pCodecCtx->extradata[4] = 0x00;
    
    //    //给extradata成员参数设置值
    //    //00 00 00 01
    //    pCodecCtx->extradata[0] = 0x00;
    //    pCodecCtx->extradata[1] = 0x00;
    //    pCodecCtx->extradata[2] = 0x00;
    //    pCodecCtx->extradata[3] = 0x01;
    //
    //    //67 42 80 1e
    //    pCodecCtx->extradata[4] = 0x67;
    //    pCodecCtx->extradata[5] = 0x42;
    //    pCodecCtx->extradata[6] = 0x80;
    //    pCodecCtx->extradata[7] = 0x1e;
    //
    //    //88 8b 40 50
    //    pCodecCtx->extradata[8] = 0x88;
    //    pCodecCtx->extradata[9] = 0x8b;
    //    pCodecCtx->extradata[10] = 0x40;
    //    pCodecCtx->extradata[11] = 0x50;
    //
    //    //1e d0 80 00
    //    pCodecCtx->extradata[12] = 0x1e;
    //    pCodecCtx->extradata[13] = 0xd0;
    //    pCodecCtx->extradata[14] = 0x80;
    //    pCodecCtx->extradata[15] = 0x00;
    //
    //    //03 84 00 00
    //    pCodecCtx->extradata[16] = 0x03;
    //    pCodecCtx->extradata[17] = 0x84;
    //    pCodecCtx->extradata[18] = 0x00;
    //    pCodecCtx->extradata[19] = 0x00;
    //
    //    //af c8 02 00
    //    pCodecCtx->extradata[20] = 0xaf;
    //    pCodecCtx->extradata[21] = 0xc8;
    //    pCodecCtx->extradata[22] = 0x02;
    //    pCodecCtx->extradata[23] = 0x00;
    //
    //    //00 00 00 01
    //    pCodecCtx->extradata[24] = 0x00;
    //    pCodecCtx->extradata[25] = 0x00;
    //    pCodecCtx->extradata[26] = 0x00;
    //    pCodecCtx->extradata[27] = 0x01;
    //
    //    //68 ce 38 80
    //    pCodecCtx->extradata[28] = 0x68;
    //    pCodecCtx->extradata[29] = 0xce;
    //    pCodecCtx->extradata[30] = 0x38;
    //    pCodecCtx->extradata[31] = 0x80;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [[self view] endEditing:YES];
}

- (int)push
{
    AVOutputFormat *ofmt = NULL;
    //输入对应一个AVFormatContext，输出对应一个AVFormatContext
    //（Input AVFormatContext and Output AVFormatContext）
    AVFormatContext *ofmt_ctx = NULL, *ifmt_ctxT = NULL;
    const char *out_filename;
    int ret, i;
    
    /* register all the codecs */
    av_register_all();
    //Network
    avformat_network_init();
    NSString *outUrl = self.outUrlTextField.text;
    if ([outUrl isEqualToString:@""] || !outUrl) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"请输入" delegate:nil cancelButtonTitle:@"确认" otherButtonTitles:nil,nil];
        [alert showAlertViewWithCompleteBlock:^(NSInteger buttonIndex) {
        }];
    }
    out_filename = [outUrl cStringUsingEncoding:NSASCIIStringEncoding];
    //    out_filename  = [[Utilities documentsPath:@"m3.MOV"] cStringUsingEncoding:NSASCIIStringEncoding];

    //输入（Input）
    if ((ret = avformat_open_input(&ifmt_ctxT, 0, &ff_avfoundation_demuxer_zws, 0)) < 0) {
        printf( "Could not open input file.");
        goto end;
    }
    if(1){
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        dispatch_async(queue, ^{
            //加入耗时操作
            dispatch_async(dispatch_get_main_queue(), ^{
                //更新UI操作
                //.....
                AVFContext *ctx         = (AVFContext*)ifmt_ctxT->priv_data;
                AVCaptureVideoPreviewLayer* previewLayer = [AVCaptureVideoPreviewLayer layerWithSession: ctx->capture_session];
                previewLayer.frame = _imageView2.frame;
                previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                
                [self.view.layer addSublayer: previewLayer];
                
            });
        });
    }
    if ((ret = avformat_find_stream_info(ifmt_ctxT, 0)) < 0) {
        printf( "Failed to retrieve input stream information");
        goto end;
    }
    //    ff_avfoundation_demuxer.read_header(ifmt_ctx);
    int videoindex=-1;
    int audioIndex = -1;
    for(i=0; i<ifmt_ctxT->nb_streams; i++){
        if(ifmt_ctxT->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
            videoindex=i;
        }
        if(ifmt_ctxT->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
            audioIndex=i;
        }
    }
    if(videoindex==-1)
    {
        printf("Couldn't find a video stream.（没有找到视频流）\n");
    }
    
        if(audioIndex==-1)
        {
            printf("Couldn't find a video stream.（没有找到音频流）\n");
        }
    
    //输出（Output）
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename); //RTMP
//        avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename);//UDP
    
    if (!ofmt_ctx) {
        printf( "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    for (i = 0; i < ifmt_ctxT->nb_streams; i++) {
        //根据输入流创建输出流（Create output AVStream according to input AVStream）
        AVStream *in_stream = ifmt_ctxT->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream) {
            printf( "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        //复制AVCodecContext的设置（Copy the settings of AVCodecContext）
        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        if (i == audioIndex) {
            [self allocExtradata:out_stream->codec];
        }
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
            out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
    }
    //Dump Format------------------
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    //打开输出URL（Open output URL）
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            printf( "Could not open output URL '%s'", out_filename);
            goto end;
        }
    }
    //写文件头（Write file header）
    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        printf( "Error occurred when opening output URL\n");
        goto end;
    }
    //    goto end;
    int frame_index=0, Aframe_index = 0;
    while (1) {
        //        @autoreleasepool {
        AVStream *in_stream, *out_stream;
        //获取一个AVPacket（Get an AVPacket）
        
        AVPacket pkt;
        av_init_packet(&pkt);
        ret = av_read_frame(ifmt_ctxT, &pkt);
        if (ret < 0)
            break;
        //FIX：No PTS (Example: Raw H.264)
        //Simple Write PTS
        if(pkt.pts==AV_NOPTS_VALUE){
            //Write PTS
            AVRational time_base1=ifmt_ctxT->streams[pkt.stream_index]->time_base;
            //Duration between 2 frames (us)
            int64_t calc_duration=(double)AV_TIME_BASE/av_q2d(ifmt_ctxT->streams[pkt.stream_index]->r_frame_rate);
            //Parameters
            pkt.pts=(double)(frame_index*calc_duration)/(double)(av_q2d(time_base1)*AV_TIME_BASE);
            pkt.dts=pkt.pts;
            pkt.duration=(double)calc_duration/(double)(av_q2d(time_base1)*AV_TIME_BASE);
        }
        
        in_stream  = ifmt_ctxT->streams[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        /* copy packet */
        //转换PTS/DTS（Convert PTS/DTS）
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, (enum AVRounding)(AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, (enum AVRounding)(AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        //        pkt.pos = -1;
        
        //Print to Screen
        if(pkt.stream_index==videoindex){
            pkt.duration = (int)av_rescale_q((int64_t)pkt.duration, in_stream->time_base, out_stream->time_base);
//            printf("Send %8d video frames to output URL pts %lld, dts %lld duration %d \n", frame_index,  pkt.pts, pkt.dts, pkt.duration);
            frame_index++;
        }
        if(pkt.stream_index==audioIndex){
            pkt.duration = (int)av_rescale_q((int64_t)pkt.duration, in_stream->time_base, out_stream->time_base);
//            printf("Send %8d audio frames to output URL pts %lld, dts %lld duration %d \n", Aframe_index,  pkt.pts, pkt.dts, pkt.duration);
            Aframe_index++;
        }
        if (pkt.stream_index == videoindex || pkt.stream_index == audioIndex) {
            ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
        }
        if (ret < 0) {
            printf( "Error muxing packet\n");
            break;
        }
        
        av_free_packet(&pkt);
//        if (Aframe_index == 100) {
//            break;
//        }
    }
    //写文件尾（Write file trailer）
    av_write_trailer(ofmt_ctx);
end:
    avformat_close_input(&ifmt_ctxT);
    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
        avio_close(ofmt_ctx->pb);
    avformat_free_context(ofmt_ctx);
    if (ret < 0 && ret != AVERROR_EOF) {
        printf( "Error occurred.\n");
        return -1;
    }
    return 0;
}

- (IBAction)outAction:(id)sender {
    av_log_set_level(AV_LOG_DEBUG);//AV_LOG_ERROR AV_LOG_DEBUG
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        [self push];
    });

//    [self performSelectorInBackground:@selector(push) withObject:nil];
}


- (void)palyLiving:(id)sender{
    //加入耗时操作
    [self localPalyer];
    [self onbutton2clicked];
    //    [self performSelectorInBackground:@selector(onbutton2clicked) withObject:nil];
}

- (IBAction)palyInputAction:(id)sender {
    
//    [self startPainting:nil];
//    [self performSelectorInBackground:@selector(startPainting:) withObject:nil];
//        [self performSelectorInBackground:@selector(palyLiving:) withObject:nil];
//        [self palyLiving:nil];
    //            [self onbutton2clicked];
    {
        NSString *inputUrl = self.inputUsrlTextField.text;
        if ([inputUrl isEqualToString:@""] || !inputUrl) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"请输入" delegate:nil cancelButtonTitle:@"确认" otherButtonTitles:nil,nil];
            [alert showAlertViewWithCompleteBlock:^(NSInteger buttonIndex) {
            }];
        }
        int n = 0;
        CGFloat pos = [[FFPlayHistoryManager default] getLastPlayInfo:inputUrl playCount:&n];
        [_player playList:@[ [[FFPlayItem alloc] initWithPath:inputUrl position:pos keyName:inputUrl] ] curIndex:0 parent:self];
    }
}

- (void)paint:(id)sender {
    @autoreleasepool {
        
        [synlock lock];
//        [_video stepFrame];
        
//        [self readPCMAndPlay:audioQueue buffer:audioQueueBuffers[0]];
        [self readRunning];
//            [_video getPacket];
        
        [synlock unlock];
    }
}

- (void)startPainting:(id)sender {
    //    [self performSelectorInBackground:@selector(onbutton2clicked) withObject:nil];
    //    [self onbutton2clicked];
    //    return;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        //加入耗时操作
        [self localPalyer];
        
        lastFrameTime = -1;
        
        // seek to 0.0 seconds
        //    [_video seekTime:0.0];
        NSTimer *testTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/10
                                                              target:self
                                                            selector:@selector(paint:)
                                                            userInfo:nil
                                                             repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:testTimer forMode:NSRunLoopCommonModes];
        
        [[NSRunLoop currentRunLoop] run];
        
        //        dispatch_async(dispatch_get_main_queue(), ^{
        //            //更新UI操作
        //            //.....
        //            if (self.video) {
        //                [self playButtonAction:nil];
        //            }
        //        });
    });
    
}

/*
 启动  ff_avfoundation_demuxer_zws 读取他的音频packet数据包解密，播放
 */
-(void)onbutton2clicked
{
    
    //    [self AVAudioSession];
    [self initAudio];
    NSLog(@"onbutton1clicked");
    AudioQueueStart(audioQueue, NULL);
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        [self readPCMAndPlay:audioQueue buffer:audioQueueBuffers[i]];
    }
    /*
     audioQueue使用的是驱动回调方式，即通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);传入一个buff去播放，播放完buffer区后通过回调通知用户,
     用户得到通知后再重新初始化buff去播放，周而复始,当然，可以使用多个buff提高效率(测试发现使用单个buff会小卡)
     */
    NSLog(@"onbutton2clicked");
}

#pragma mark -
#pragma mark player call back
/*
 试了下其实可以不用静态函数，但是c写法的函数内是无法调用[self ***]这种格式的写法，所以还是用静态函数通过void *input来获取原类指针
 这个回调存在的意义是为了重用缓冲buffer区，当通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);函数放入queue里面的音频文件播放完以后，通过这个函数通知
 调用者，这样可以重新再使用回调传回的AudioQueueBufferRef
 */
static void AudioPlayerAQInputCallback(void *input, AudioQueueRef outQ, AudioQueueBufferRef outQB)
{
    NSLog(@"AudioPlayerAQInputCallback");
    AVCallController *mainviewcontroller = (__bridge AVCallController *)input;
    [mainviewcontroller checkUsedQueueBuffer:outQB];
    [mainviewcontroller readPCMAndPlay:outQ buffer:outQB];
}


-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf
{
    if(qbuf == audioQueueBuffers[0])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 0");
    }
    if(qbuf == audioQueueBuffers[1])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 1");
    }
    if(qbuf == audioQueueBuffers[2])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 2");
    }
    if(qbuf == audioQueueBuffers[3])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 3");
    }
}

-(void)initAudio
{
    ///设置音频参数
    audioDescription.mSampleRate = 44100;//采样率
    audioDescription.mFormatID = kAudioFormatLinearPCM;//kAudioFormatMPEG4AAC kAudioFormatLinearPCM
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 1;///单声道
    audioDescription.mFramesPerPacket = 1;//每一个packet一侦数据
    audioDescription.mBitsPerChannel = 16;//每个采样点16bit量化
    audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel/8) * audioDescription.mChannelsPerFrame;
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame ;
    
    
    //    audioDescription.mFormatID = kAudioFormatMPEG4AAC;
    //    audioDescription.mSampleRate = 44100;
    //    audioDescription.mChannelsPerFrame = 1;
    
    ///创建一个新的从audioqueue到硬件层的通道
    //  AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);///使用当前线程播
    AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, (__bridge void *)(self), nil, nil, 0, &audioQueue);//使用player的内部线程播
    ////添加buffer区
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        int result =  AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    }
}

-(NSInteger)fifoAction{
    return [self readRunning];
}

//ffmpeg 转码后再播音
-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB{
    
    @autoreleasepool {
    [synlock lock];
    
    size_t totalLength = 0;
    
    Byte *samples = NULL;
    
    totalLength = [self fifoAction]; //[self pushRead];//[self fifoAction];
    
    samples = frame_buf;//pkt.data;
    
    NSLog(@"read raw data size = %ld",totalLength);
    outQB->mAudioDataByteSize = totalLength;
    Byte *audiodata = (Byte *)outQB->mAudioData;
    for(int i=0;i<totalLength;i++)
    {
        audiodata[i] = samples[i];
    }
    /*
     将创建的buffer区添加到audioqueue里播放
     AudioQueueBufferRef用来缓存待播放的数据区，AudioQueueBufferRef有两个比较重要的参数，AudioQueueBufferRef->mAudioDataByteSize用来指示数据区大小，AudioQueueBufferRef->mAudioData用来保存数据区
     */
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    
//    av_free_packet(&pkt);
    [synlock unlock];
    }
}

@end

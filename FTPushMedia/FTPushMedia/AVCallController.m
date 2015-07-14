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
#import "Utilities.h"
#import "UIAlertView+Block.h"
AVCallController *ttt;
UIImage* CVImageBufferRef2UIImage(CVImageBufferRef imageBuffer);
CVPixelBufferRef pixelBufferFromCGImage(CGImageRef image);
struct AVFPixelFormatSpec {
    enum AVPixelFormat ff_id;
    OSType avf_id;
};
@interface AVCallController (){
    
    float lastFrameTime;
}
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

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
/*
 - (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
 self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
 if (self) {
 // Custom initialization.
 }
 return self;
 }
 */
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
//    [self createControl];
    ttt = self;
}


 // Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
 - (void)viewDidLoad {
 [super viewDidLoad];
     
     // video images are landscape, so rotate image view 90 degrees
     [_imageVIew setTransform:CGAffineTransformMakeRotation(M_PI/2)];
 }


/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations.
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

#pragma mark -
#pragma mark createControl
- (void)createControl
{
    //UI展示
    self.view.backgroundColor = [UIColor grayColor];
    labelState = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, 220, 30)];
    labelState.backgroundColor = [UIColor clearColor];
    [self.view addSubview:labelState];
    [labelState release];
    
    btnStartVideo = [[UIButton alloc] initWithFrame:CGRectMake(20, 350, 80, 50)];
    [btnStartVideo setTitle:@"Star" forState:UIControlStateNormal];
    
    [btnStartVideo setBackgroundImage:[UIImage imageNamed:@"Images/button.png"] forState:UIControlStateNormal];
    [btnStartVideo addTarget:self action:@selector(startVideoCapture) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnStartVideo];
    [btnStartVideo release];
    
    UIButton* stop = [[UIButton alloc] initWithFrame:CGRectMake(120, 350, 80, 50)];
    [stop setTitle:@"Stop" forState:UIControlStateNormal];
    
    [stop setBackgroundImage:[UIImage imageNamed:@"Images/button.png"] forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(stopVideoCapture:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stop];
    [stop release];
    
    localView = [[UIView alloc] initWithFrame:CGRectMake(40, 50, 200, 300)];
    [self.view addSubview:localView];
    [localView release];
    
}
#pragma mark -
#pragma mark VideoCapture
- (AVCaptureDevice *)getFrontCamera
{
    //获取前置摄像头设备
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameras)
    {
        if (device.position == AVCaptureDevicePositionFront)
            return device;
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
}

- (void)startVideoCapture
{
    //    av_log_set_level(AV_LOG_DEBUG);
    //    //    [self localPalyer];
    //    [self performSelectorInBackground:@selector(push) withObject:nil];
    //    //    [self performSelectorInBackground:@selector(push2) withObject:nil];
    //    return;
    //打开摄像设备，并开始捕抓图像
    [labelState setText:@"Starting Video stream"];
    if(self->avCaptureDevice || self->avCaptureSession)
    {
        [labelState setText:@"Already capturing"];
        return;
    }
    
    if((self->avCaptureDevice = [self getFrontCamera]) == nil)
    {
        [labelState setText:@"Failed to get valide capture device"];
        return;
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:self->avCaptureDevice error:&error];
    if (!videoInput)
    {
        [labelState setText:@"Failed to get video input"];
        self->avCaptureDevice = nil;
        return;
    }
    
    self->avCaptureSession = [[AVCaptureSession alloc] init];
    self->avCaptureSession.sessionPreset = AVCaptureSessionPresetLow;
    [self->avCaptureSession addInput:videoInput];
    
    // Currently, the only supported key is kCVPixelBufferPixelFormatTypeKey. Recommended pixel format choices are
    // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange or kCVPixelFormatType_32BGRA.
    // On iPhone 3G, the recommended pixel format choices are kCVPixelFormatType_422YpCbCr8 or kCVPixelFormatType_32BGRA.
    //
    AVCaptureVideoDataOutput *avCaptureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    for (NSNumber *pxl_fmt in [avCaptureVideoDataOutput availableVideoCVPixelFormatTypes]) {
        if ([pxl_fmt intValue] == AV_PIX_FMT_YUV420P)
            
            NSLog(@"%x : %x", [pxl_fmt intValue], AV_PIX_FMT_YUV420P);
    }
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],//kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange kCVPixelFormatType_32BGRA
                              kCVPixelBufferPixelFormatTypeKey,
                              //                              [NSNumber numberWithInt:240], (id)kCVPixelBufferWidthKey,
                              //                              [NSNumber numberWithInt:320], (id)kCVPixelBufferHeightKey,
                              nil];
    avCaptureVideoDataOutput.videoSettings = settings;
    [settings release];
    /*We create a serial queue to handle the processing of our frames*/
    dispatch_queue_t queue = dispatch_queue_create("org.doubango.idoubs", NULL);
    [avCaptureVideoDataOutput setSampleBufferDelegate:self queue:queue];
    [self->avCaptureSession addOutput:avCaptureVideoDataOutput];
    [avCaptureVideoDataOutput release];
    dispatch_release(queue);
    
    //    AVCaptureVideoPreviewLayer* previewLayer = [AVCaptureVideoPreviewLayer layerWithSession: self->avCaptureSession];
    //    previewLayer.frame = localView.bounds;
    //    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    //
    //    [self->localView.layer addSublayer: previewLayer];
    
    self->firstFrame = YES;
    [self->avCaptureSession startRunning];
    
    [labelState setText:@"Video capture started"];
    
}

- (void)payler{
    //    [self->avCaptureSession stopRunning];
    AVCaptureVideoPreviewLayer* previewLayer = [AVCaptureVideoPreviewLayer layerWithSession: self->avCaptureSession];
    previewLayer.frame = localView.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    [self->localView.layer addSublayer: previewLayer];
    //    [self->avCaptureSession startRunning];
}

- (void)stopVideoCapture:(id)arg
{
    [self payler];
    return;
    //停止摄像头捕抓
    if(self->avCaptureSession){
        [self->avCaptureSession stopRunning];
        self->avCaptureSession = nil;
        [labelState setText:@"Video capture stopped"];
    }
    self->avCaptureDevice = nil;
    //移除localView里面的内容
    for (UIView *view in self->localView.subviews) {
        [view removeFromSuperview];
    }
}

- (UIImage*)CVPixelBufferRef2UIImage:(CVPixelBufferRef)pixelBuffer{
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(pixelBuffer),
                                                 CVPixelBufferGetHeight(pixelBuffer))];
    
    UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
    return uiImage;
}
- (void)imageLoad:(CVPixelBufferRef)pixelBuffer{
    self.imageVIew.image = [self CVPixelBufferRef2UIImage:pixelBuffer];
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    
    //    CVImageBufferRef image_buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    //    UIImage *image = CVImageBufferRef2UIImage(image_buffer);
    //    self.imageVIew.image = image;
    
    //    [self outputSampleBuffer:sampleBuffer];
    //    return;
    //捕捉数据输出 要怎么处理虽你便
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    //    [self performSelectorOnMainThread:@selector(imageLoad:) withObject:pixelBuffer waitUntilDone:NO];
    /*Lock the buffer*/
    if(CVPixelBufferLockBaseAddress(pixelBuffer, 0) == kCVReturnSuccess)
    {
        //        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddress(pixelBuffer);
        //        size_t buffeSize = CVPixelBufferGetDataSize(pixelBuffer);
        
        if(self->firstFrame)
        {
            if(1)
            {
                //第一次数据要求：宽高，类型
                int width = CVPixelBufferGetWidth(pixelBuffer);
                int height = CVPixelBufferGetHeight(pixelBuffer);
                
                int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
                switch (pixelFormat) {
                    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                        //TMEDIA_PRODUCER(producer)->video.chroma = tmedia_nv12; // iPhone 3GS or 4
                        NSLog(@"Capture pixel format=NV12");
                        break;
                    case kCVPixelFormatType_422YpCbCr8:
                        //TMEDIA_PRODUCER(producer)->video.chroma = tmedia_uyvy422; // iPhone 3
                        NSLog(@"Capture pixel format=UYUY422");
                        break;
                    default:
                        //TMEDIA_PRODUCER(producer)->video.chroma = tmedia_rgb32;
                        NSLog(@"Capture pixel format=RGB32");
                        break;
                }
                
                self->firstFrame = NO;
            }
        }
        /*We unlock the buffer*/
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    //    [self stdio:sampleBuffer];
}


-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height {
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       32,
                                       pict.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

- (void)stdio:(CMSampleBufferRef)sampleBuffer{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // access the data
    int width = CVPixelBufferGetWidth(pixelBuffer);
    int height = CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *rawPixelBase = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    AVPicture pict;
    avpicture_alloc(&pict, PIX_FMT_RGB32, width, height);
    AVFrame *pFrame = (AVFrame *)&pict;
    //    pFrame->quality = 0;
    AVFrame* outpic;
    outpic = avcodec_alloc_frame();
    
    avpicture_fill((AVPicture*)pFrame, rawPixelBase, PIX_FMT_RGB32, width, height);//PIX_FMT_RGB32//PIX_FMT_RGB8 PIX_FMT_NV21
    width = 192;
    height = 144;
    
    avcodec_register_all();
    av_register_all();
    
    AVCodec *codec, *pCodec;
    AVCodecContext *c= NULL;
    AVCodecContext *cp= NULL;
    int  out_size, size, outbuf_size;
    //    FILE *fp;
    uint8_t *outbuf;
    
    printf("Video encoding\n");
    
    //    /* find the mpeg video encoder */
    codec =avcodec_find_encoder(CODEC_ID_H264);//avcodec_find_encoder_by_name("libx264"); //avcodec_find_encoder(CODEC_ID_H264);//CODEC_ID_H264); AV_CODEC_ID_VP6
    //
    if (!codec) {
        fprintf(stderr, "codec not found\n");
        exit(1);
    }
    //
    c= avcodec_alloc_context3(codec);
    {
        pCodec = avcodec_find_decoder(CODEC_ID_H264);
        cp= avcodec_alloc_context3(pCodec);
        
        /* put sample parameters */
        cp->bit_rate = 400000;
        //    c->bit_rate_tolerance = 10;
        //    c->me_method = 2;
        /* resolution must be a multiple of two */
        cp->width =width;//192;//width;//352;
        cp->height = height;//144;//height;//288;
        /* frames per second */
        cp->time_base= (AVRational){1,25};
        cp->gop_size = 12;//25; /* emit one intra frame every ten frames */
        cp->max_b_frames=1;
        cp->pix_fmt = PIX_FMT_YUV420P;
        cp->thread_count = 1;
        /* open it */
        if (avcodec_open2(cp, pCodec,NULL) < 0) {
            fprintf(stderr, "could not open codec\n");
            exit(1);
        }
        
    }
    
    /* put sample parameters */
    c->bit_rate = 400000;
    //    c->bit_rate_tolerance = 10;
    //    c->me_method = 2;
    /* resolution must be a multiple of two */
    c->width =width;//192;//width;//352;
    c->height = height;//144;//height;//288;
    /* frames per second */
    c->time_base= (AVRational){1,25};
    c->gop_size = 12;//25; /* emit one intra frame every ten frames */
    c->max_b_frames=1;
    c->pix_fmt = PIX_FMT_YUV420P;
    c->thread_count = 1;
    
    //    c ->me_range = 16;
    //    c ->max_qdiff = 4;
    //    c ->qmin = 10;
    //    c ->qmax = 51;
    //    c ->qcompress = 0.6f;
    
    
    
    /* open it */
    if (avcodec_open2(c, codec,NULL) < 0) {
        fprintf(stderr, "could not open codec\n");
        exit(1);
    }
    
    //    c = [self encoderContext:0 h:0];
    
    /* alloc image and output buffer */
    outbuf_size = 400000;
    outbuf = malloc(outbuf_size);
    size = c->width * c->height;
    AVPacket avpkt, avpkte;
    int nbytes = avpicture_get_size(c->pix_fmt, c->width, c->height);
    //create buffer for the output image
    uint8_t* outbuffer = (uint8_t*)av_malloc(nbytes);
    
    fflush(stdout);
    //    for (int i=0;i<15;++i){
    out_size = avpicture_fill((AVPicture*)outpic, outbuffer, c->pix_fmt, c->width, c->height);
    
    struct SwsContext* fooContext = sws_getContext(c->width, c->height,
                                                   PIX_FMT_RGB32,
                                                   c->width, c->height,
                                                   c->pix_fmt,
                                                   SWS_POINT, NULL, NULL, NULL);
    
    //perform the conversion
    //            pFrame->data[0]  += pFrame->linesize[0] * (height - 1);
    //        pFrame->linesize[0] *= -1;
    //        pFrame->data[1]  += pFrame->linesize[1] * (height / 2 - 1);
    //        pFrame->linesize[1] *= -1;
    //        pFrame->data[2]  += pFrame->linesize[2] * (height / 2 - 1);
    //        pFrame->linesize[2] *= -1;
    
    int xx = sws_scale(fooContext,(const uint8_t**)pFrame->data, pFrame->linesize, 0, c->height, outpic->data, outpic->linesize);
    //        int xx = sws_scale(fooContext,(const uint8_t**)pFrame->data, pFrame->linesize, 0, c->height, pict.data, pict.linesize);
    // Here is where I try to convert to YUV
    NSLog(@"xxxxx=====%d",xx);
    
    /* encode the image */
    int got_packet_ptr = 0;
    av_init_packet(&avpkt);
    //            avpkt.size = outbuf_size;
    //    avpkt.data = outbuf;
    avpkt.size = 0;
    avpkt.data = NULL;
    
    //    av_init_packet(&avpkte);
    //    //            avpkt.size = outbuf_size;
    //    //    avpkt.data = outbuf;
    //    avpkte.size = 0;
    //    avpkte.data = NULL;
    
    //        out_size = avcodec_encode_video2(c, &avpkt, outpic, &got_packet_ptr);
    static int pts = 0;
    outpic->pts = pts;
    avpkt.pts = pts++;
    //    img_convert(&pict, PIX_FMT_RGB32, outpic, c->pix_fmt, c->width, c->height);
    
    
    
    do {
        out_size = avcodec_encode_video2(c, &avpkt, outpic, &got_packet_ptr); //*... handle received packet*/
        //        out_size = avcodec_encode_video2(c, &avpkt, pFrame, &got_packet_ptr); //*... handle received packet*/
    } while(!got_packet_ptr);
    
    printf("encoding frame (size=%d)\n", avpkt.size);
    printf("%d encoding frame %s\n", pts, avpkt.data);
    //        AVFrame *cpFrame = avcodec_alloc_frame();
    //
    //        do {
    //            out_size = avcodec_decode_video2(cp, cpFrame, &got_packet_ptr, &avpkt);
    //
    //            printf("encoding frame (size=%d)\n", avpkt.size);
    //            printf("encoding frame %s\n", avpkt.data);
    //        } while(!got_packet_ptr);
    //
    //    do {
    //        out_size = avcodec_encode_video2(c, &avpkte, cpFrame, &got_packet_ptr); //*... handle received packet*/
    //        //        out_size = avcodec_encode_video2(c, &avpkt, pFrame, &got_packet_ptr); //*... handle received packet*/
    //
    //        printf("encoding frame (size=%d)\n", avpkte.size);
    //        printf("encoding frame %s\n", avpkte.data);
    //    } while(!got_packet_ptr);
    //    NSLog(@"%d", pFrame);
    //        AVFrame *cp2Frame = avcodec_alloc_frame();
    //        int cp2Frames = avpicture_get_size(PIX_FMT_RGB32, c->width, c->height);
    //        uint8_t* outbuffercp2 = (uint8_t*)av_malloc(cp2Frames);
    //        out_size = avpicture_fill((AVPicture*)cp2Frame, outbuffercp2, PIX_FMT_RGB32, c->width, c->height);
    //
    //        fooContext = sws_getContext(c->width, c->height,
    //                                    PIX_FMT_YUV420P,//PIX_FMT_RGB24 PIX_FMT_RGB32 PIX_FMT_YUV420P
    //                                    c->width, c->height,
    //                                    PIX_FMT_RGB32,
    //                                    SWS_FAST_BILINEAR, NULL, NULL, NULL);//SWS_FAST_BILINEAR
    //        xx = sws_scale(fooContext,(const uint8_t**)cpFrame->data, cpFrame->linesize, 0, c->height, cp2Frame->data, cp2Frame->linesize);
    //        [self testImageFromAVPicture:*(AVPicture*)cp2Frame aAVPicture:*(AVPicture*)pFrame width:width height:height];
    
    //    [self testImageFromAVPicture:*(AVPicture*)outpic width:width height:height];
    //    return;
    if (got_packet_ptr==1){
        
        //        av_usleep(1000000);
        [self uploadData:&avpkt toRTMP:c];
        //        [self testPacket:&avpkt codec:c];
    }
    //        fwrite(avpkt.data,1,avpkt.size ,fp);
    //    }
    //    fclose(fp);
    
    av_free_packet(&avpkt);
    free(outbuf);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    avcodec_close(c);
    av_free(c);
    //    av_free(pFrame);
    av_free(outpic);
}

- (void)outputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    // sampleBuffer now contains an individual frame of raw video frames
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // access the data
    int width = CVPixelBufferGetWidth(pixelBuffer);
    int height = CVPixelBufferGetHeight(pixelBuffer);
    int bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    unsigned char *rawPixelBase = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    
    // Convert the raw pixel base to h.264 format
    //    AVCodec *codec = 0;
    AVCodecContext *context = 0;
    AVFrame *frame = 0;
    AVPacket packet;
    
    //    avcodec_init();
    avcodec_register_all();
    //    for (enum AVCodecID i = AV_CODEC_ID_NONE; i <= AV_CODEC_ID_MVC2_DEPRECATED; i++) {
    //
    //        codec = avcodec_find_encoder(i);
    //        if (codec == 0) {
    //            //            NSLog(@"%x : Codec not found!!", i);
    //        }else{
    //            NSLog(@"%d : Codec found!!", i);
    //        }
    //    }
    
    context = [self context:width h:height];
    
    
    // Create the frame
    frame = avcodec_alloc_frame();
    if (!frame) {
        NSLog(@"Unable to alloc frame");
        return;
    }
    frame->format = context->pix_fmt;
    frame->width = context->width;
    frame->height = context->height;
    
    
    avpicture_fill((AVPicture *) frame, rawPixelBase, context->pix_fmt, frame->width, frame->height);
    static int pts = 0;
    frame->pts = pts;
    int got_output = 0;
    av_init_packet(&packet);
    packet.data = rawPixelBase;
    
    
    int y_size = context->width * context->height;
    //    av_new_packet(&packet,y_size*3);
    //    packet.size = y_size*3;
    
    //    packet.pts = pts++;
    do {
        avcodec_encode_video2(context, &packet, frame, &got_output); //*... handle received packet*/
    } while(!got_output);
    //    avcodec_encode_video2(context, &packet, frame, &got_output);
    
    // Unlock the pixel data
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    // Send the data over the network
    
    if (got_output==1){
        [self uploadData:&packet toRTMP:nil];
    }
}

- (AVCodecContext *)encoderContext:(int)w h:(int)h{
    static AVCodec *codec = 0;
    static AVCodecContext *context = 0;
    if (context) {
        return context;
    }
    codec = avcodec_find_encoder(AV_CODEC_ID_H264);//libx264  AV_CODEC_ID_RAWVIDEO AV_CODEC_ID_CYUV AV_CODEC_ID_H263 AV_CODEC_ID_VP6F
    //    codec =  avcodec_find_encoder_by_name("libx264");
    if (codec == 0) {
        NSLog(@"Codec not found!!");
        return nil;
    }
    
    context = avcodec_alloc_context3(codec);
    
    AVFormatContext *ofmt_ctx1 = [self ofmt_ctx];
    for (int i = 0; i < ofmt_ctx1->nb_streams; i++) {
        //根据输入流创建输出流（Create output AVStream according to input AVStream）
        AVStream *in_stream = ofmt_ctx1->streams[i];
        if (in_stream->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            if(1){
                AVStream * i_video_stream = in_stream;
                context->bit_rate = i_video_stream->codec->bit_rate; //400000;
                //                c->bit_rate = 400000;
                context->codec_id = i_video_stream->codec->codec_id;
                context->codec_type = i_video_stream->codec->codec_type;
                context->time_base.num = i_video_stream->time_base.num;
                context->time_base.den = i_video_stream->time_base.den;
                fprintf(stderr, "time_base.num = %d time_base.den = %d\n", context->time_base.num, context->time_base.den);
                context->width = i_video_stream->codec->width;
                context->height = i_video_stream->codec->height;
                context->pix_fmt = i_video_stream->codec->pix_fmt;
                printf("%d %d %d", context->width, context->height, context->pix_fmt);
                context->flags = i_video_stream->codec->flags;
                context->flags |= CODEC_FLAG_GLOBAL_HEADER;
                context->me_range = i_video_stream->codec->me_range;
                context->max_qdiff = i_video_stream->codec->max_qdiff;
                
                //                    c->qmin = i_video_stream->codec->qmin;
                //                    c->qmax = i_video_stream->codec->qmax;
                
                context->qcompress = i_video_stream->codec->qcompress;
            }
            
            //            context = ofmt_ctx1->streams[i]->codec;
        }
    }
    if (avcodec_open2(context, codec, 0) < 0) {
        NSLog(@"Unable to open codec");
        return nil;
    }
    return context;
}

- (AVCodecContext *)context:(int)w h:(int)h{
    AVCodec *codec = 0;
    static AVCodecContext *context = 0;
    if (context) {
        return context;
    }
    codec = avcodec_find_decoder(AV_CODEC_ID_H264);//libx264  AV_CODEC_ID_RAWVIDEO AV_CODEC_ID_CYUV AV_CODEC_ID_H263 AV_CODEC_ID_VP6F
    //    codec =  avcodec_find_encoder_by_name("libx264");
    if (codec == 0) {
        NSLog(@"Codec not found!!");
        return nil;
    }
    
    //    context = avcodec_alloc_context3(codec);
    
    AVFormatContext *ofmt_ctx1 = [self ofmt_ctx];
    for (int i = 0; i < ofmt_ctx1->nb_streams; i++) {
        //根据输入流创建输出流（Create output AVStream according to input AVStream）
        AVStream *in_stream = ofmt_ctx1->streams[i];
        if (in_stream->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            context = ofmt_ctx1->streams[i]->codec;
        }
    }
    if (avcodec_open2(context, codec, 0) < 0) {
        NSLog(@"Unable to open codec");
        return nil;
    }
    return context;
}

- (void)testImageFromAVPicture:(AVPicture)pict aAVPicture:(AVPicture)pict2 width:(int)width height:(int)height {
    __block UIImage *image = [self imageFromAVPicture:pict width:width height:height];
    __block UIImage *image2 = [self imageFromAVPicture:pict2 width:width height:height];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        //加入耗时操作
        dispatch_async(dispatch_get_main_queue(), ^{
            //更新UI操作
            //.....
            self.imageVIew.image = image;
            self.imageView2.image = image2;
        });
    });
    NSLog(@"%@", image);
}

- (void)testImageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height {
    __block UIImage *image = [self imageFromAVPicture:pict width:width height:height];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        //加入耗时操作
        dispatch_async(dispatch_get_main_queue(), ^{
            //更新UI操作
            //.....
            self.imageVIew.image = image;
        });
    });
    NSLog(@"%@", image);
}

- (void)testPacket:(AVPacket *)packet codec:(AVCodecContext *)pCodecCtx{
    
    self.video = [[VideoFrameExtractor alloc] init];
    [self.video setPCodecCtx:pCodecCtx];
    [self.video setupScaler];
    
    {
        AVFrame *pFrame;
        AVPicture outPict;
        avpicture_alloc(&outPict, PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height);
        pFrame = (AVFrame *)&outPict;
        int frameFinished=0;
        //            if(packet.stream_index==videoStream) {
        // Decode video frame
        avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, packet);
        [self.video  setPFrame:pFrame];
        UIImage *image  = _video.currentImage;
        NSLog(@"%@", image);
    }
    
    
}


- (AVFormatContext *)ofmt_ctxAnd:(AVCodecContext *)c{
    AVOutputFormat *ofmt = NULL;
    //输入对应一个AVFormatContext，输出对应一个AVFormatContext
    //（Input AVFormatContext and Output AVFormatContext）
    static AVFormatContext *ofmt_ctx = NULL;
    const char *out_filename;
    int ret;
    
    if (ofmt_ctx) {
        return ofmt_ctx;
    }
    out_filename = "rtmp://172.18.1.203/live/t2";//输出 URL（Output URL）[RTMP]
    
    av_register_all();
    //Network
    avformat_network_init();
    
    //输出（Output）
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename); //RTMP
    //        avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename);//UDP
    
    if (!ofmt_ctx) {
        printf( "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    {
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, c->codec);
        if (!out_stream) {
            printf( "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        //复制AVCodecContext的设置（Copy the settings of AVCodecContext）
        ret = avcodec_copy_context(out_stream->codec, c);
        if (ret < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        //        out_stream->codec->width = 192;
        //        out_stream->codec->height = 144;
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
    return ofmt_ctx;
    
end:
    return NULL;
}

- (AVFormatContext *)ofmt_ctx{
    AVOutputFormat *ofmt = NULL;
    //输入对应一个AVFormatContext，输出对应一个AVFormatContext
    //（Input AVFormatContext and Output AVFormatContext）
    static AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    AVPacket pkt;
    const char *in_filename, *out_filename;
    int ret, i;
    
    if (ofmt_ctx) {
        return ofmt_ctx;
    }
    in_filename  = [[Utilities bundlePath:@"m4.MOV"] cStringUsingEncoding:NSASCIIStringEncoding];
    out_filename = "rtmp://172.18.1.203/live/t2";//输出 URL（Output URL）[RTMP]
    
    av_register_all();
    //Network
    avformat_network_init();
    //输入（Input）
    if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0)) < 0) {
        printf( "Could not open input file.");
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        printf( "Failed to retrieve input stream information");
        goto end;
    }
    
    int videoindex=-1;
    for(i=0; i<ifmt_ctx->nb_streams; i++)
        if(ifmt_ctx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
            videoindex=i;
            break;
        }
    
    av_dump_format(ifmt_ctx, 0, in_filename, 0);
    
    //输出（Output）
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename); //RTMP
    //        avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename);//UDP
    
    if (!ofmt_ctx) {
        printf( "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt = ofmt_ctx->oformat;
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        //根据输入流创建输出流（Create output AVStream according to input AVStream）
        AVStream *in_stream = ifmt_ctx->streams[i];
        if (in_stream->codec->codec_type != AVMEDIA_TYPE_VIDEO) {
            continue;
        }
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
        out_stream->codec->width = 192;
        out_stream->codec->height = 144;
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
    
    int frame_index=0;
    return ofmt_ctx;
    
end:
    return NULL;
}

- (int)uploadData:(AVPacket*)packet toRTMP:(id)obj{
    
    
    AVFormatContext *ofmt_ctx1 = [self ofmt_ctx];
    //    AVFormatContext *ofmt_ctx1 = [self ofmt_ctxAnd:(AVCodecContext *)obj];
    if (!ofmt_ctx1) {
        printf( "t1Error occurred when opening output URL\n");
        return -1;
    }
    int ret1 = av_interleaved_write_frame(ofmt_ctx1, packet);
    if (ret1 < 0) {
        printf( "Error occurred when opening output URL\n");
    }
    return 0 ;
    AVOutputFormat *ofmt = NULL;
    static AVFormatContext *ofmt_ctx = NULL, *ifmt_ctxT = NULL;
    //    AVPacket pkt;
    const char *in_filename, *out_filename;
    static int ret, i = 0;
    packet->pts = i;
    packet->dts = i++;
    if (ofmt_ctx) {
        ret = av_interleaved_write_frame(ofmt_ctx, packet);
        //        av_free_packet(packet);
        if (ret < 0) {
            printf( "Error occurred when opening output URL\n");
        }
        return 0;
    }
    out_filename = "rtmp://172.18.1.229/live/t2";//输出 URL（Output URL）[RTMP]
    
    av_register_all();
    //Network
    avformat_network_init();
    
    
    //输出（Output）
    
    //    avformat_alloc_output_context2(&ofmt_ctx, NULL, "", out_filename); //RTMP
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename); //RTMP
    //        avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename);//UDP
    
    if (!ofmt_ctx) {
        printf( "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    
    AVCodecContext *context = [self context:192 h:144];
    
    ofmt = ofmt_ctx->oformat;
    {
        //根据输入流创建输出流（Create output AVStream according to input AVStream）
        //        AVStream *in_stream = ifmt_ctxT->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, context->codec);
        if (!out_stream) {
            printf( "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        //复制AVCodecContext的设置（Copy the settings of AVCodecContext）
        ret = avcodec_copy_context(out_stream->codec, context);
        if (ret < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            goto end;
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
    int frame_index=0;
    //    return 0;
    int64_t start_time=av_gettime();
    ret = av_interleaved_write_frame(ofmt_ctx, packet);
    
    if (ret < 0) {
        printf( "Error muxing packet\n");
    }
    
    //    av_free_packet(packet);
    //    av_write_trailer(ofmt_ctx);
end:
    //    avformat_close_input(&ifmt_ctxT);
    //    /* close output */
    //    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE))
    //    avio_close(ofmt_ctx->pb);
    //    avformat_free_context(ofmt_ctx);
    //    if (ret < 0 && ret != AVERROR_EOF) {
    //        printf( "Error occurred.\n");
    //        return -1;
    //    }
    return 0;
}
#if 1

extern AVInputFormat ff_avfoundation_demuxer;

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

-(IBAction)playButtonAction:(id)sender {
    lastFrameTime = -1;
    
    // seek to 0.0 seconds
//    [_video seekTime:0.0];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                     target:self
                                   selector:@selector(displayNextFrame:)
                                   userInfo:nil
                                    repeats:YES];
}

- (IBAction)showTime:(id)sender {
    NSLog(@"current time: %f s",_video.currentTime);
}

#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)

-(void)displayNextFrame:(NSTimer *)timer {
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    if (![_video stepFrame]) {
//        [timer invalidate];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        _imageVIew.image = _video.currentImage;
    });
    float frameTime = 1.0/([NSDate timeIntervalSinceReferenceDate]-startTime);
    if (lastFrameTime<0) {
        lastFrameTime = frameTime;
    } else {
        lastFrameTime = LERP(frameTime, lastFrameTime, 0.8);
    }
    NSLog(@"%@", [NSString stringWithFormat:@"%.0f",lastFrameTime]);
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
    AVPacket pkt;
    const char *out_filename;
    int ret, i;
    NSString *outUrl = self.outUrlTextField.text;
    if ([outUrl isEqualToString:@""] || !outUrl) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"请输入" delegate:nil cancelButtonTitle:@"确认" otherButtonTitles:nil,nil];
        [alert showAlertViewWithCompleteBlock:^(NSInteger buttonIndex) {
        }];
    }
    out_filename = [outUrl cStringUsingEncoding:NSASCIIStringEncoding];
    
    av_register_all();
    //Network
    avformat_network_init();
    //输入（Input）
    if ((ret = avformat_open_input(&ifmt_ctxT, 0, &ff_avfoundation_demuxer, 0)) < 0) {
        printf( "Could not open input file.");
        goto end;
    }
    {
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
    for(i=0; i<ifmt_ctxT->nb_streams; i++)
        if(ifmt_ctxT->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
            videoindex=i;
            break;
        }
    if(videoindex==-1)
    {
        printf("Couldn't find a video stream.（没有找到视频流）\n");
        //        return -1;
    }
    
    //输出（Output）
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename); //RTMP
    //    avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename);//UDP
    
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
    int frame_index=0;
    //    return 0;
    int64_t start_time=av_gettime();
    while (1) {
        //        @autoreleasepool {
        AVStream *in_stream, *out_stream;
        //获取一个AVPacket（Get an AVPacket）
        ret = av_read_frame(ifmt_ctxT, &pkt);
        if (ret < 0)
            break;
        ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
        
        if (ret < 0) {
            printf( "Error muxing packet\n");
            break;
        }
        
        av_free_packet(&pkt);
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

#endif


- (IBAction)outAction:(id)sender {
    
    av_log_set_level(AV_LOG_DEBUG);//AV_LOG_ERROR AV_LOG_DEBUG
    //    [self localPalyer];
    [self performSelectorInBackground:@selector(push) withObject:nil];
}

- (IBAction)palyInputAction:(id)sender {
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        //加入耗时操作
        [self localPalyer];
        
        lastFrameTime = -1;
        
        // seek to 0.0 seconds
        //    [_video seekTime:0.0];
        
        NSTimer *testTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                         target:self
                                       selector:@selector(displayNextFrame:)
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
@end
//

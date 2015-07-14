//
//  main.m
//  FTPushMedia
//
//  Created by ZWS on 14-11-12.
//  Copyright (c) 2014年 FTSafe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

#import "Utilities.h"
#import "libavutil/avstring.h"
#import "libavcodec/avcodec.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}



int flush_encoder(AVFormatContext *fmt_ctx,unsigned int stream_index)
{
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    while (1) {
        printf("Flushing stream #%u encoder\n", stream_index);
        //ret = encode_write_frame(NULL, stream_index, &got_frame);
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame)
        {ret=0;break;}
        printf("编码成功1帧！\n");
        /* mux encoded frame */
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}

int main1(int argc, char * argv[])
{
//    return mainT(argc, argv);
    
    
    AVFormatContext* pFormatCtx;
    AVOutputFormat* fmt;
    AVStream* video_st;
    AVCodecContext* pCodecCtx;
    AVCodec* pCodec;
    
    uint8_t* picture_buf;
    AVFrame* picture;
    int size;
    
    const char *in_filename  = [[Utilities bundlePath:@"src01_480x272.yuv"] cStringUsingEncoding:NSASCIIStringEncoding];
    FILE *in_file = fopen(in_filename, "rb");	//视频YUV源文件
    int in_w=480,in_h=272;//宽高
    int framenum=20;
    const char* out_file = [[Utilities bundlePath:@"m2.MOV"] cStringUsingEncoding:NSASCIIStringEncoding];					//输出文件路径 @"outf.h264"
    out_file = "rtmp://172.18.1.203/live/t2";//输出 URL（Output URL）[RTMP]
    
    av_register_all();
    
    avformat_network_init();
    //方法1.组合使用几个函数
    pFormatCtx = avformat_alloc_context();
    //猜格式
//    fmt = av_guess_format(NULL, out_file, NULL);
//    pFormatCtx->oformat = fmt;
    
    //方法2.更加自动化一些
//    avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
    avformat_alloc_output_context2(&pFormatCtx, NULL, "flv", out_file); //RTMP
    fmt = pFormatCtx->oformat;
    
    
    //注意输出路径
    int error = avio_open(&pFormatCtx->pb,out_file, AVIO_FLAG_WRITE);
    if (error < 0)
    {
        printf("输出文件打开失败");
        return -1;
    }
    
    video_st = avformat_new_stream(pFormatCtx, 0);
    if (video_st==NULL)
    {
        return -1;
    }
    pCodecCtx = video_st->codec;
    pCodecCtx->codec_id = fmt->video_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = PIX_FMT_YUV420P;
    pCodecCtx->width = in_w;
    pCodecCtx->height = in_h;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 25;
    pCodecCtx->bit_rate = 400000;
    pCodecCtx->gop_size=250;
    //H264
    //pCodecCtx->me_range = 16;
    //pCodecCtx->max_qdiff = 4;
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    //pCodecCtx->qcompress = 0.6;
    //输出格式信息
    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec)
    {
        printf("没有找到合适的编码器！\n");
        return -1;
    }
    if (avcodec_open2(pCodecCtx, pCodec,NULL) < 0)
    {
        printf("编码器打开失败！\n");
        return -1;
    }
    picture = avcodec_alloc_frame();
    size = avpicture_get_size(pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    picture_buf = (uint8_t *)av_malloc(size);
    avpicture_fill((AVPicture *)picture, picture_buf, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    //写文件头
    avformat_write_header(pFormatCtx,NULL);
    
    AVPacket pkt;
    int y_size = pCodecCtx->width * pCodecCtx->height;
    av_new_packet(&pkt,y_size*3);
    
    for (int i=0; i<framenum; i++){
        //读入YUV
        if (fread(picture_buf, 1, y_size*3/2, in_file) < 0)
        {
            printf("文件读取错误\n");
            return -1;
        }else if(feof(in_file)){
            break;
        }
        picture->data[0] = picture_buf;  // 亮度Y
        picture->data[1] = picture_buf+ y_size;  // U
        picture->data[2] = picture_buf+ y_size*5/4; // V
        //PTS
        picture->pts=i;
        int got_picture=0;
        //编码
        int ret = avcodec_encode_video2(pCodecCtx, &pkt,picture, &got_picture);
        if(ret < 0)
        {
            printf("编码错误！\n");
            return -1;
        }
        if (got_picture==1)
        {
            printf("编码成功第%d帧！\n",i);
            pkt.stream_index = video_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }
    }
    
    //Flush Encoder
//    int ret = flush_encoder(pFormatCtx,0);
//    if (ret < 0) {
//        printf("Flushing encoder failed\n");
//        return -1;
//    }
    
    //写文件尾
    av_write_trailer(pFormatCtx);
    
    //清理
    if (video_st)
    {
        avcodec_close(video_st->codec);
        av_free(picture);
        av_free(picture_buf);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
    
    fclose(in_file);
    
    return 0;
}



/***
 ***/
//static void SaveFrame(AVFrame *pFrame, int width, int height, int iFrame)
//{
//    FILE *pFile;
//    char szFilename[255];
//    int  y;
//    
//    // Open file
//    memset(szFilename, 0, sizeof(szFilename));
//    snprintf(szFilename, 255, "./bmptest/%03d.ppm", iFrame);
//    system("mkdir -p ./bmptest");
//    pFile=fopen(szFilename, "wb");
//    if(pFile==NULL)
//        return;
//    
//    // Write header
//    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
//    
//    // Write pixel data
//    for(y = 0; y < height; y++)
//        fwrite(pFrame->data[0]+y*pFrame->linesize[0], 1, width*3, pFile);
//    
//    // Close file
//    fclose(pFile);
//}
//
//
//int mainT(int argc, char **argv)
//{
//    AVFormatContext *pFormatCtx = NULL;
//    int err, i;
//    char *filename = "alan.mp4"; // argv[1];
//    AVCodec *pCodec = NULL;
//    AVCodecContext *pCodecCtx;
//    AVFrame *pFrame;
//    AVFrame *pFrameRGB;
//    uint8_t *buffer;
//    int numBytes;
//    int frameFinished;
//    AVPacket packet;
//    int videoStream;
//    struct SwsContext *pSwsCtx;
//    
//    av_log_set_level(AV_LOG_DEBUG);
//    
//    av_log(NULL, AV_LOG_INFO, "Playing: %s\n", filename);
//    
//    av_register_all();
//    
//    pFormatCtx = avformat_alloc_context();
//    //    pFormatCtx->interrupt_callback.callback = decode_interrupt_cb;
//    //    pFormatCtx->interrupt_callback.opaque = NULL;
//    err = avformat_open_input(&pFormatCtx, filename, NULL, NULL);
//    if (err < 0) {
//        av_log(NULL, AV_LOG_ERROR, "open_input fails, ret = %d\n", err);
//        return -1;
//    }
//    
//    err = avformat_find_stream_info(pFormatCtx, NULL);
//    if (err < 0) {
//        av_log(NULL, AV_LOG_WARNING, "could not find codec\n");
//        return -1;
//    }
//    
//    av_dump_format(pFormatCtx, 0, filename, 0);
//    
//    av_log(NULL, AV_LOG_INFO, "nb_streams in %s = %d\n", filename, pFormatCtx->nb_streams);
//    videoStream = -1;
//    for (i = 0; i < pFormatCtx->nb_streams; i++) {
//        if(pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
//            videoStream=i;
//            av_log(NULL, AV_LOG_DEBUG, "video stream index = %d\n", i,
//                   pFormatCtx->streams[i]->codec->codec_type);
//            break;
//        }
//    }
//    if(videoStream==-1) {
//        av_log(NULL, AV_LOG_ERROR, "Haven't find video stream.\n");
//        return -1; // Didn't find a video stream
//    }
//    
//    // Find decoder
//    pCodecCtx=pFormatCtx->streams[i]->codec;
//    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
//    if (!pCodec) {
//        av_log(NULL, AV_LOG_ERROR, "%s: avcodec_find_decoder fails\n", filename);
//        return -1;
//    }
//    
//    // Open pCodec
//    if(avcodec_open(pCodecCtx, pCodec)<0) {
//        av_log(NULL, AV_LOG_ERROR, "%s: avcodec_open fails\n", filename);
//        return -1; // Could not open codec
//    }
//    
//    // Allocate video frame
//    pFrame=avcodec_alloc_frame();
//    if(pFrame == NULL)
//        return -1;
//    
//    // Allocate an AVFrame structure
//    pFrameRGB = avcodec_alloc_frame();
//    if(pFrameRGB == NULL)
//        return -1;
//    
//    // Determine required buffer size and allocate buffer
//    numBytes = avpicture_get_size(PIX_FMT_RGB24, pCodecCtx->width, pCodecCtx->height);
//    buffer = (uint8_t *)av_malloc(numBytes * sizeof(uint8_t));
//    avpicture_fill((AVPicture *)pFrameRGB, buffer, PIX_FMT_RGB24,
//                   pCodecCtx->width, pCodecCtx->height);
//    
//    pSwsCtx = sws_getContext (pCodecCtx->width,
//                              pCodecCtx->height,
//                              pCodecCtx->pix_fmt,
//                              pCodecCtx->width,
//                              pCodecCtx->height,
//                              PIX_FMT_RGB24,
//                              SWS_BICUBIC,
//                              NULL, NULL, NULL);
//    i=0;
//    while(av_read_frame(pFormatCtx, &packet) >= 0) {
//        if(packet.stream_index == videoStream) { // Is this a packet from the video stream?
//            avcodec_decode_video2(pCodecCtx,
//                                  pFrame,
//                                  &frameFinished,
//                                  &packet); // Decode video frame
//            
//            if(frameFinished) { // Did we get a video frame?
//                av_log(NULL, AV_LOG_DEBUG, "Frame %d decoding finished.\n", i);
//                // Save the frame to disk
//                if(i++ < 5) {
//                    //转换图像格式，将解压出来的YUV的图像转换为BRG24的图像
//                    sws_scale(pSwsCtx,
//                              pFrame->data,
//                              pFrame->linesize,
//                              0,
//                              pCodecCtx->height,
//                              pFrameRGB->data,
//                              pFrameRGB->linesize);
//                    // 保存为PPM
//                    SaveFrame(pFrameRGB, pCodecCtx->width, pCodecCtx->height, i);
//                }
//                else {
//                    break;
//                }
//            }
//            else {
//                av_log(NULL, AV_LOG_DEBUG, "Frame not finished.\n");
//            }
//        }
//        
//        av_free_packet(&packet); // Free the packet that was allocated by av_read_frame
//    }
//    sws_freeContext (pSwsCtx);
//    
//    av_free (pFrame);
//    av_free (pFrameRGB);
//    av_free (buffer);
//    avcodec_close (pCodecCtx);
//    av_close_input_file (pFormatCtx);
//    return 0;
//}

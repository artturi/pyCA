#!/bin/bash

# point to your config file
SCRIPTRC=/opt/pyCA/etc/scriptrc

. $SCRIPTRC


CAMSOURCE="v4l2src device=/dev/video0 ! video/x-raw-rgb, framerate=25/1"
VENC="x264enc tune=zerolatency byte-stream=true bitrate=$BITRATE"

VENC="x264enc tune=zerolatency byte-stream=true bitrate=$BITRATE"
SCREENSOURCE="v4l2src device=/dev/dada0 ! video/x-raw-yuv,format=\(fourcc\)YUY2,width=800,height=640, framerate=25/1"
AUDIOSOURCE="alsasrc device=hw:1"


if [ "$DURATION" -gt "0" ]; then
  PREFIX="timeout $DURATION"
fi

if [ "$REFERER" == "pyca" ]; then
  SUFFIX=" | :"
fi

if [ "$LIVERECORD" == "live" ]; then
  if [ "$LIVEFORMAT" == "smallCameraBigPresentation" ]; then
    eval $PREFIX gst-launch  -v \
        $CAMSOURCE ! ffmpegcolorspace !  videoscale ! video/x-raw-yuv,width=480,height=300 ! deinterlace fields=top ! \
        queue ! videomixer name=mix ! \
        $VENC ! flvmux name="mux" \
        $AUDIOSOURCE ! ffenc_aac ! mux. \
        mux. ! rtmpsink location="rtmp://$DEST/molitor-amphi2/mp4:live.sdp" \
        $SCREENSOURCE !  ffmpegcolorspace ! videobox border-alpha=1.0 top=0  left=-480 !  mix. $SUFFIX
  elif [ "$LIVEFORMAT" == "camera" ]; then
    eval $PREFIX gst-launch  -v \
        $CAMSOURCE ! ffmpegcolorspace !  deinterlace fields=top ! \
        queue ! $VENC ! flvmux name="mux" \
        $AUDIOSOURCE ! ffenc_aac ! queue ! mux. \
        mux. ! rtmpsink location="rtmp://$DEST/molitor-amphi2/mp4:live.sdp" $SUFFIX
  fi
elif [ "$LIVERECORD" == "liverecord" ]; then
  if [ "$LIVEFORMAT" == "smallCameraBigPresentation" ]; then
    GST_DEBUG=*:5 eval $PREFIX gst-launch  -v --gst-debug-level=2 \
        $CAMSOURCE ! ffmpegcolorspace ! tee name="camera" ! videoscale ! video/x-raw-yuv,width=480,height=300 ! deinterlace fields=top ! \
        queue ! videomixer name=mix ! \
        $VENC ! flvmux name="mux" \
        $AUDIOSOURCE !  tee name="audio" ! ffenc_aac ! queue ! mux. \
        mux. ! rtmpsink location="rtmp://$DEST/molitor-amphi2/mp4:live.sdp" \
        $SCREENSOURCE !  ffmpegcolorspace ! tee name="screen" ! videobox border-alpha=1.0 top=0  left=-480 !  queue ! mix. \
        screen. ! $VENC ! queue ! filesink location="$DIR/$NAME-screen.avi" 
        audio. ! audioconvert ! wavenc ! queue ! filesink location="$DIR/$NAME-audio.wav" $SUFFIX
        camera. ! $VENC ! queue ! filesink location="$DIR/$NAME-camera.avi" 

# eval $PREFIX gst-launch  -v --gst-debug-level=2 \
#        gstrtpbin name=rtpbin \
#          $CAMSOURCE ! ffmpegcolorspace ! tee name="camera" ! videoscale ! video/x-raw-yuv,width=480,height=300 ! deinterlace fields=top ! \
#          queue ! videomixer name=mix ! $VENC ! tee name="matrix" ! fakesink \
#          $SCREENSOURCE !  ffmpegcolorspace ! tee name="screen" ! videobox border-alpha=1.0 top=0  left=-480 !  queue ! mix. \
#            matrix. ! rtph264pay ! rtpbin.send_rtp_sink_0 \
#            rtpbin.send_rtp_src_0 ! $VRTPSINK \
#            rtpbin.send_rtcp_src_0 ! $VRTCPSINK \
#            $VRTCPSRC ! rtpbin.recv_rtcp_sink_0 \
#          $AUDIOSOURCE !  tee name="audio" ! faac ! rtpmp4apay ! rtpbin.send_rtp_sink_1 \
#              rtpbin.send_rtp_src_1 ! $ARTPSINK \
##              rtpbin.send_rtcp_src_1 ! $ARTCPSINK  \
#               $ARTCPSRC ! rtpbin.recv_rtcp_sink_1 \
#          matrix. ! queue ! filesink location="/tmp/pip.avi"

#  gst-launch -v gstrtpbin name=rtpbin \
#        $VSOURCE ! $VENC ! rtph264pay ! rtpbin.send_rtp_sink_0                   \
#                rtpbin.send_rtp_src_0 ! $VRTPSINK                                         \
#                rtpbin.send_rtcp_src_0 ! $VRTCPSINK                                       \
#            $VRTCPSRC ! rtpbin.recv_rtcp_sink_0                                            \
#        $ASOURCE ! $AENC ! rtpbin.send_rtp_sink_1                                         \
#        rtpbin.send_rtp_src_1 ! $ARTPSINK                                                 \
#        rtpbin.send_rtcp_src_1 ! $ARTCPSINK                                               \
#      $ARTCPSRC ! rtpbin.recv_rtcp_sink_1


  elif [ "$LIVEFORMAT" == "camera" ]; then
    eval $PREFIX gst-launch  -v \
        $CAMSOURCE ! ffmpegcolorspace ! tee name="camera" ! deinterlace fields=top ! \
        queue ! $VENC ! flvmux name="mux" \
        $AUDIOSOURCE !  tee name="audio" ! ffenc_aac ! mux. \
        mux.    ! rtmpsink location="rtmp://$DEST/molitor-amphi2/mp4:live.sdp" \
        $SCREENSOURCE ! ffmpegcolorspace ! $VENC ! queue ! filesink location="$DIR/$NAME-screen.avi" \
        audio.  ! audioconvert ! wavenc ! queue !  filesink location="$DIR/$NAME-audio.wav" \
        camera. ! $VENC ! queue ! filesink location="$DIR/$NAME-camera.avi" $SUFFIX
        
  fi
elif [ "$LIVERECORD" == "record" ]; then
  eval $PREFIX gst-launch  -v \
      $CAMSOURCE    ! ffmpegcolorspace ! x264enc ! queue ! filesink location="$DIR/$NAME-camera.avi" \
      $AUDIOSOURCE  ! audioconvert ! wavenc ! queue !  filesink location="$DIR/$NAME-audio.wav" \
      $SCREENSOURCE ! ffmpegcolorspace ! x264enc ! queue ! filesink location="$DIR/$NAME-screen.avi" $SUFFIX
fi

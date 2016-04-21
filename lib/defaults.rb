module Ffmprb

  File.image_extname_regex = /^\.(jpe?g|a?png|y4m)$/i
  File.sound_extname_regex = /^\.(mp3|wav)$/i
  File.movie_extname_regex = /^\.(mp4|flv|mov)$/i

  Filter.silence_noise_max_db = -40

  # NOTE ducking is currently not for streams
  Process.duck_audio_silent_min = 3
  Process.duck_audio_transition_length = 1
  Process.duck_audio_transition_in_start = -0.4
  Process.duck_audio_transition_out_start = -0.6
  Process.duck_audio_volume_hi = 0.9
  Process.duck_audio_volume_lo = 0.1
  Process.timeout = 30

  Process.input_video_auto_rotate = false
  Process.input_video_fps = nil  # NOTE the documented ffmpeg default is 25

  Process.output_video_resolution = CGA
  Process.output_video_fps = 16
  Process.output_audio_encoder = 'libmp3lame'

  Util.cmd_timeout = 30
  Util.ffmpeg_cmd = %w[ffmpeg -y]
  Util.ffmpeg_inputs_max = 31
  Util.ffprobe_cmd = ['ffprobe']

  Util::ThreadedIoBuffer.blocks_max = 1024
  Util::ThreadedIoBuffer.block_size = 64*1024
  Util::ThreadedIoBuffer.timeout = 1
  Util::ThreadedIoBuffer.timeout_limit = 15
  # NOTE all this effectively sets the minimum throughput: blocks_max * blocks_size / timeout * timeout_limit
  Util::ThreadedIoBuffer.io_wait_timeout = 1

  Util::Thread.timeout = 15


  # NOTE http://12factor.net etc

  Ffmprb.ffmpeg_debug = ENV.fetch('FFMPRB_FFMPEG_DEBUG', '') !~ Ffmprb::ENV_VAR_FALSE_REGEX
  Ffmprb.debug = ENV.fetch('FFMPRB_DEBUG', '') !~ Ffmprb::ENV_VAR_FALSE_REGEX

  proc_vis_firebase = ENV['FFMPRB_PROC_VIS_FIREBASE']
  if Ffmprb::FIREBASE_AVAILABLE
    fail Error, "Please provide just the name of the firebase in FFMPRB_PROC_VIS_FIREBASE (e.g. my-proc-vis-io for https://my-proc-vis-io.firebaseio.com/proc/)"  if proc_vis_firebase =~ /\//
    Ffmprb.proc_vis_firebase = proc_vis_firebase
  elsif proc_vis_firebase
    Ffmprb.logger.warn "Firebase unavailable (have firebase gem installed or unset FFMPRB_PROC_VIS_FIREBASE to get rid of this warning)"
  end

end

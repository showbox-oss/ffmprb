module Ffmprb

  Filter.silence_noise_max_db = -40

  Process.duck_audio_hi = 0.9
  Process.duck_audio_lo = 0.1
  Process.duck_audio_silent_min_sec = 3
  Process.duck_audio_transition_sec = 1
  Process.timeout = 15

  Util.ffmpeg_cmd = ['ffmpeg']
  Util.ffprobe_cmd = ['ffprobe']

  Util::ThreadedIoBuffer.blocks_max = 1024
  Util::ThreadedIoBuffer.block_size = 64*1024
  Util::ThreadedIoBuffer.timeout = 9

end

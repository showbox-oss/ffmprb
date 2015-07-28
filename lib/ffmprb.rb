require 'ffmprb/execution'
require 'ffmprb/file'
require 'ffmprb/filter'
require 'ffmprb/find_silence'
require 'ffmprb/process'
require 'ffmprb/util'
require 'ffmprb/version'

require 'logger'

module Ffmprb

  ENV_VAR_FALSE_REGEX = /^(0|no?|false)?$/i

  QVGA = '320x240'
  HD_720p = '1280x720'
  HD_1080p = '1920x1080'

  class Error < StandardError
  end

  Util.ffmpeg_cmd = ['ffmpeg']
  Util.ffprobe_cmd = ['ffprobe']

  Process.duck_audio_hi = 0.9
  Process.duck_audio_lo = 0.1
  Process.duck_audio_transition_sec = 1
  Process.duck_audio_silent_min_sec = 3
  Filter.silence_noise_max_db = -40

  Util::IoBuffer.blocks_max = 1024
  Util::IoBuffer.block_size = 64*1024
  Util::IoBuffer.timeout = 9

  class << self

    def process(*args, &blk)
      logger.debug "Starting process with #{args} in #{blk.source_location}"
      Process.new.tap do |process|
        if blk
          process.instance_exec *args, &blk
          process.run
          logger.debug "Finished process with #{args} in #{blk.source_location}"
        end
      end
    end
    alias :action! :process  # ;)

    attr_accessor :debug

    def logger
      @logger ||= Logger.new(STDERR).tap do |logger|
        logger.level = debug ? Logger::DEBUG : Logger::INFO
      end
    end

    def logger=(logger)
      @logger.close  if @logger
      @logger = logger
    end

  end

end

Ffmprb.debug = ENV.fetch('FFMPRB_DEBUG', '') !~ Ffmprb::ENV_VAR_FALSE_REGEX

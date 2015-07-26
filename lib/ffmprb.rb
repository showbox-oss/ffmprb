require 'ffmprb/file'
require 'ffmprb/filter'
require 'ffmprb/process'
require 'ffmprb/util'
require 'ffmprb/version'

require 'logger'
require 'time'
require 'timeout'

module Ffmprb

  ENV_VAR_FALSE_REGEX = /^(0|no?|false)?$/i

  QVGA = '320x240'
  HD_720p = '1280x720'
  HD_1080p = '1920x1080'

  class Error < StandardError
  end

  Util.ffmpeg_cmd = 'ffmpeg'
  Util.ffprobe_cmd = 'ffprobe'

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

    def find_silence(input_file, output_file)
      logger.debug "Finding silence (#{input_file.path}->#{output_file.path})"
      filters = Filter.silencedetect
      options = ['-i', input_file.path, *Filter.complex_options(filters), output_file.path]
      silence = []
      Util.ffmpeg(*options).split("\n").each do |line|
        next  unless line =~ /^\[silencedetect\s.*\]\s*silence_(\w+):\s*(\d+\.?d*)/
        case $1
        when 'start'
          silence << OpenStruct.new(start_at: $2.to_f)
        when 'end'
          if silence.empty?
            silence << OpenStruct.new(start_at: 0.0, end_at: $2.to_f)
          else
            raise Error, "ffmpeg is being stupid: silence_end with no silence_start"  if silence.last.end_at
            silence.last.end_at = $2.to_f
          end
        else
          Ffmprb.warn "Unknown silence mark: #{$1}"
        end
      end

      logger.debug "Found silence (#{input_file.path}->#{output_file.path}): [#{silence.map{|t,v| "#{t}: #{v}"}}]"
      silence
    end

  end

end

Ffmprb.debug = ENV.fetch('FFMPRB_DEBUG', '') !~ Ffmprb::ENV_VAR_FALSE_REGEX

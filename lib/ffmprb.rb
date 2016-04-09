require 'logger'
require 'ostruct'

# IMPORTANT NOTE ffmprb uses threads internally, however, it is not "thread-safe"

module Ffmprb

  ENV_VAR_FALSE_REGEX = /^(0|no?|false)?$/i

  CGA = '320x200'
  QVGA = '320x240'
  HD_720p = '1280x720'
  HD_1080p = '1920x1080'

  class Error < StandardError; end

  class << self

    # TODO limit:
    def process(*args, **opts, &blk)
      fail Error, "process: nothing ;( gimme a block!"  unless blk

      process = Process.new(**opts)

      logger.debug "Starting process with #{args} in #{blk.source_location}"

      process.instance_exec *args, &blk
      logger.debug "Initialized process with #{args} in #{blk.source_location}"

      process.run.tap do
        logger.debug "Finished process with #{args} in #{blk.source_location}"
      end
    end
    alias :action! :process  # ;)

    attr_accessor :debug, :ffmpeg_debug

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


# NOTE http://12factor.net etc

Ffmprb.ffmpeg_debug = ENV.fetch('FFMPRB_FFMPEG_DEBUG', '') !~ Ffmprb::ENV_VAR_FALSE_REGEX
Ffmprb.debug = ENV.fetch('FFMPRB_DEBUG', '') !~ Ffmprb::ENV_VAR_FALSE_REGEX


require_relative 'ffmprb/execution'
require_relative 'ffmprb/file'
require_relative 'ffmprb/filter'
require_relative 'ffmprb/find_silence'
require_relative 'ffmprb/process'
require_relative 'ffmprb/util'

require 'defaults'

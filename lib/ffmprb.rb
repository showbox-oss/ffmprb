require 'ffmprb/file'
require 'ffmprb/filter'
require 'ffmprb/process'
require 'ffmprb/util'
require 'ffmprb/version'

require 'logger'

ENV_VAR_FALSE_REGEX = /^(0|no?|false)?$/i

module Ffmprb

  QVGA = '320x240'
  HD_1080p = '1920x1080'

  class Error < Exception
  end

  class << self

    def process(*args, &blk)
      logger.debug "Starting process with #{args} in #{blk.source_location}"
      Process.new(*args, &blk).tap do |process|
        logger.debug "Finished process with #{args} in #{blk.source_location}"
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

Ffmprb.debug = ENV.fetch('FFMPRB_DEBUG', '') !~ ENV_VAR_FALSE_REGEX

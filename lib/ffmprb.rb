require 'logger'

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
    def process(*args, &blk)
      fail Error, "process: nothing ;( gimme a block!"  unless blk

      process = Process.new

      logger.debug "Starting process with #{args} in #{blk.source_location}"

      process.instance_exec *args, &blk
      logger.debug "Initialized process with #{args} in #{blk.source_location}"

      process.run.tap do
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

Ffmprb.debug = ENV.fetch('FFMPRB_DEBUG', '') !~ Ffmprb::ENV_VAR_FALSE_REGEX

Dir["#{__FILE__.slice /(.*).rb$/, 1}/**/*.rb"].each{|f| require f}

require 'defaults'

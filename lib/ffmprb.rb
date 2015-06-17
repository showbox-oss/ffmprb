require 'ffmprb/version'
require 'ffmprb/util'
require 'ffmprb/file'
require 'ffmprb/process'

require 'logger'

module Ffmprb

  QVGA = '320x240'
  HD_1080p = '1920x1080'

  class Error < Exception
  end

  class << self

    def logger
      @logger ||= Logger.new(STDERR)
    end

    def logger=(logr)
      @logger.close  if @logger
      @logger = logr
    end

  end

end

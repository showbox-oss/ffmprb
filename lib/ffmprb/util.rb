require 'open3'

module Ffmprb

  module Util

    def self.ffprobe(args)
      sh "ffprobe #{args}"
    end

    def self.ffmpeg(args)
      sh "ffmpeg -y #{args}"
    end

    def self.sh(cmd)
      Ffmprb.logger.info cmd
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        # XXX timeouting/cleanup here will be appreciated
        raise Error.new("#{cmd}:\n#{stderr.read}")  unless wait_thr.value.exitstatus == 0
        stdout.read
      end
    end

  end

end

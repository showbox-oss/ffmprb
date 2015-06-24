require 'open3'

module Ffmprb

  module Util

    def self.ffprobe(args)
      sh "ffprobe#{args}"
    end

    def self.ffmpeg(args)
      args = " -loglevel debug #{args}"  if Ffmprb.debug
      sh "ffmpeg -y#{args}"
    end

    def self.sh(cmd, output: :stdout, log: :stderr)
      Ffmprb.logger.info cmd
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        # XXX timeouting/cleanup here will be appreciated

        std_err = ''
        log_cmd = "#{cmd.split(' ').first.upcase}: "  if log == :stderr
        while s = stderr.gets
          Ffmprb.logger.debug log_cmd + s.chomp  if log == :stderr
          std_err << s
        end

        raise Error.new "#{cmd}:\n#{std_err}"  unless wait_thr.value.exitstatus == 0

        case output
        when :stderr
          std_err
        when :stdout
          stdout.read
        end
      end
    end

  end

end

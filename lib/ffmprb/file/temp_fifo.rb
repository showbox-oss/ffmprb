module Ffmprb

  class File

    class TempFifo < File  # NOTE lazy, on-demand one

      def initialize(extname)
        @mode = :write
        @extname = extname
      end

      def path
        @path ||= File.temp_fifo_path(extname).tap do |path|
          ::File.mkfifo path
          Ffmprb.logger.debug "Created temp fifo with path: #{path}"
        end
      end

    end

  end

end

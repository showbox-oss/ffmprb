require 'json'
require 'mkfifo'
require 'tempfile'

module Ffmprb

  class File

    class << self

      def threaded_buffered_fifo(extname='.tmp')
        input_fifo_file = temp_fifo(extname)
        output_fifo_file = temp_fifo(extname)
        Ffmprb.logger.debug "Opening #{input_fifo_file.path}>#{output_fifo_file.path} for buffering"
        Util::Thread.new do
          begin
            Util::ThreadedIoBuffer.new async_opener(input_fifo_file, 'r'), async_opener(output_fifo_file, 'w')
            Util::Thread.join_children!
            Ffmprb.logger.debug "IoBuffering from #{input_fifo_file.path} to #{output_fifo_file.path} ended"
          ensure
            input_fifo_file.remove  if input_fifo_file
            output_fifo_file.remove  if output_fifo_file
          end
        end
        Ffmprb.logger.debug "IoBuffering from #{input_fifo_file.path} to #{output_fifo_file.path} started"

        # XXX see threaded_io_buffer's XXX yield buff  if block_given?

        [input_fifo_file, output_fifo_file]
      end

      def create(path)
        new(path: path, mode: :write).tap do |file|
          Ffmprb.logger.debug "Created file with path: #{file.path}"
        end
      end

      def open(path)
        new(path: (path.respond_to?(:path)? path.path : path), mode: :read).tap do |file|
          Ffmprb.logger.debug "Opened file with path: #{file.path}"
        end
      end

      def temp(extname)
        file = create(Tempfile.new(['', extname]))
        Ffmprb.logger.debug "Created temp file with path: #{file.path}"

        return file  unless block_given?

        begin
          yield file
        ensure
          begin
            FileUtils.remove_entry file.path
          rescue
            Ffmprb.logger.warn "Error removing temp file with path #{file.path}: #{$!.message}"
          end
          Ffmprb.logger.debug "Removed temp file with path: #{file.path}"
        end
      end

      def temp_fifo(extname='.tmp', &blk)
        fifo_file = create(temp_fifo_path extname)
        ::File.mkfifo fifo_file.path

        return fifo_file  unless block_given?

        begin
          yield
        ensure
          fifo_file.remove
        end
      end

      def temp_fifo_path(extname)
        ::File.join Dir.tmpdir, Dir::Tmpname.make_tmpname('', 'p' + extname)
      end

      protected

      # NOTE must be timeout-safe
      def async_opener(file, mode)
        ->{
          Ffmprb.logger.debug "Trying to open #{file.path} for #{mode}-buffering"
          ::File.open(file.path, mode)
        }
      end

    end


    def initialize(path:, mode:)
      @path = path
      @path.close  if @path && @path.respond_to?(:close)  # NOTE specially for temp files
      path!  # NOTE early (exception) raiser
      @mode = mode.to_sym
      fail Error, "Open for read, create for write, ??? for #{@mode}"  unless %i[read write].include?(@mode)
    end

    def path
      path!
    end

    # Info

    def exist?
      ::File.exist? path
    end

    def extname
      ::File.extname path
    end

    def channel?(medium)
      case medium
      when :video
        image_extname? || movie_extname?
      when :audio
        sound_extname? || movie_extname?
      end
    end

    def length
      return @duration  if @duration

      # NOTE first attempt
      @duration = probe['format']['duration']
      @duration &&= @duration.to_f
      return @duration  if @duration

      # NOTE a harder try
      @duration = probe(true)['frames'].reduce(0) do |sum, frame|
        sum + frame['pkt_duration_time'].to_f
      end
    end

    def resolution
      v_stream = probe['streams'].first
      "#{v_stream['width']}x#{v_stream['height']}"
    end


    # Manipulation

    def read
      ::File.read path
    end
    def write(s)
      ::File.write path, s
    end

    def remove
      FileUtils.remove_entry path
      Ffmprb.logger.debug "Removed file with path: #{path}"
      @path = nil
    end

    private

    def path!
      (  # NOTE specially for temp files
        @path.respond_to?(:path)? @path.path : @path
      ).tap do |path|
        # XXX ensure readabilty/writability/readiness
        fail Error, "'#{path}' is un#{@mode.to_s[0..3]}able"  unless path && !path.empty?
      end
    end

    def probe(harder=false)
      return @probe  unless !@probe || harder
      cmd = ['-v', 'quiet', '-i', path, '-print_format', 'json', '-show_format', '-show_streams']
      cmd << '-show_frames'  if harder
      @probe = JSON.parse(Util::ffprobe *cmd).tap do |probe|
        fail Error, "This doesn't look like a ffprobable file"  unless probe['streams']
      end
    end

    def image_extname?
      extname =~ /^\.(jpe?g|png|y4m)$/i
    end

    def sound_extname?
      extname =~ /^\.(mp3|wav)$/i
    end

    def movie_extname?
      extname =~ /^\.(mp4|flv)$/i
    end

  end

end

require 'ffmprb/file/sample'

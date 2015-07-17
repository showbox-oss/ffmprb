require 'json'
require 'mkfifo'
require 'tempfile'

module Ffmprb

  class File

    class << self

      def buffered_fifos(extname='.tmp', &blk)
        output_fifo_file = create(tmp_fifo_path extname)
        ::File.mkfifo output_fifo_file.path
        input_fifo_file = output_fifo_file.buffered_fifo_to(&blk)

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
          rescue => e
            Ffmprb.logger.error "Error removing temp file with path #{file.path}: #{e.message}"
          end
          Ffmprb.logger.debug "Removed temp file with path: #{file.path}"
        end
      end

      def tmp_fifo_path(extname)
        ::File.join Dir.tmpdir, Dir::Tmpname.make_tmpname('', 'p' + extname)
      end

    end


    def initialize(path:, mode:)
      @path = path
      @path.close  if @path && @path.respond_to?(:close)  # NOTE specially for temp files
      path!  # NOTE early (exception) raiser
      @mode = mode.to_sym
      raise Error, "Open for read, create for write, ??? for #{@mode}"  unless %i[read write].include?(@mode)
    end

    def path
      path!
    end

    # Info

    def extname
      ::File.extname path
    end

    def length
      @duration ||= probe['format']['duration']
      return @duration.to_f  if @duration

      @duration = probe(true)['frames'].reduce(0){|sum, frame| sum + frame['pkt_duration_time'].to_f}
    end

    def resolution
      v_stream = probe['streams'].first
      "#{v_stream['width']}x#{v_stream['height']}"
    end


    def sample(  # NOTE can snap output (an image) or audio (a sound) or both
      at: 0.01,
      video: true,
      audio: nil
    )
      audio = File.temp('.mp3')  if audio == true
      video = File.temp('.jpg')  if video == true

      Ffmprb.logger.debug "Snap shooting files, video path: #{video ? video.path : 'NONE'}, audio path: #{audio ? audio.path : 'NONE'}"

      raise Error, "Incorrect output extname (must be .jpg)"  unless !video || video.extname =~ /jpe?g$/
      raise Error, "Incorrect audio extname (must be .mp3)"  unless !audio || audio.extname =~ /mp3$/
      raise Error, "Can sample either video OR audio UNLESS a block is given"  unless block_given? || (!!audio != !!video)

      cmd = " -i #{path}"
      cmd << " -deinterlace -an -ss #{at} -r 1 -vcodec mjpeg -f mjpeg #{video.path}"  if video
      cmd << " -vn -ss #{at} -t 1 -f mp3 #{audio.path}"  if audio
      Util.ffmpeg cmd

      return video || audio  unless block_given?

      begin
        yield *[video || nil, audio || nil].compact
      ensure
        begin
          video.remove  if video
          audio.remove  if audio
          Ffmprb.logger.debug "Removed sample files"
        rescue
          Ffmprb.logger.warn "Error removing sample files: #{$!.message}"
        end
      end
    end

    # Manipulation

    def remove
      FileUtils.remove_entry path
      Ffmprb.logger.debug "Removed file with path: #{path}"
      @path = nil
    end

    # Utility

    def buffered_fifo_to(&blk)
      File.create(self.class.tmp_fifo_path extname).tap do |fifo_file|
        ::File.mkfifo fifo_file.path

        Thread.new "buffer (#{fifo_file.path}->#{path})" do  # NOTE because fifo won't open one-sided, blocks until open both for read and write
          buff = Util::Buffer.new(::File.open(fifo_file.path, 'r'), ::File.open(path, 'w'))
          buff.once :terminated do
            Ffmprb.logger.debug "Buffering from #{fifo_file.path} to #{path} ended"
            buff.input.close
            buff.output.close
          end
          Ffmprb.logger.debug "Buffering from #{fifo_file.path} to #{path} started"

          yield buff  if block_given?
        end
      end
    end

    private

    def path!
      (  # NOTE specially for temp files
        @path.respond_to?(:path)? @path.path : @path
      ).tap do |path|
        # XXX ensure readabilty/writability/readiness
        raise Error, "'#{path}' is un#{@mode.to_s[0..3]}able"  unless path && !path.empty?
      end
    end

    def probe(force=false)
      return @probe  unless !@probe || force
      cmd = " -v quiet -i #{path} -print_format json -show_format -show_streams"
      cmd << " -show_frames"  if force
      @probe = JSON.parse(Util::ffprobe cmd).tap do |probe|
        raise Error, "This doesn't look like a ffprobable file"  unless probe['streams']
      end
    end

  end

end

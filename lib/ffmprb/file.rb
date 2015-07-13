require 'json'
require 'tempfile'

module Ffmprb

  class File

    def self.open(path)
      new(path: (path.respond_to?(:path)? path.path : path), mode: :read).tap do |file|
        Ffmprb.logger.debug "Opened file with path: #{file.path}"
      end
    end

    def self.create(path)
      new(path: path, mode: :write).tap do |file|
        Ffmprb.logger.debug "Created file with path: #{file.path}"
      end
    end

    def self.temp(extname)
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

    def initialize(path:, mode:)
      @path = path
      @path.close  if @path && @path.respond_to?(:close)  # NOTE specially for temp files
      path!  # NOTE early (exception) raiser
      @mode = mode.to_sym
      raise Error.new "Open for read, create for write, ??? for #{@mode}"  unless %i[read write].include?(@mode)
    end

    def path
      path!
    end

    def extname
      ::File.extname path
    end

    # Info

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

      raise Error.new "Incorrect output extname (must be .jpg)"  unless !video || video.extname =~ /jpe?g$/
      raise Error.new "Incorrect audio extname (must be .mp3)"  unless !audio || audio.extname =~ /mp3$/
      raise Error.new "Can sample either video OR audio UNLESS a block is given"  unless block_given? || (!!audio != !!video)

      cmd = " -i #{path}"
      cmd << " -deinterlace -an -ss #{at} -r 1 -vcodec mjpeg -f mjpeg #{video.path}"  if video
      cmd << " -vn -ss #{at} -t 1 -f mp3 #{audio.path}"  if audio
      Ffmprb::Util.ffmpeg cmd

      return video || audio  unless block_given?

      begin
        yield *[video || nil, audio || nil].compact
      ensure
        begin
          video.remove  if video
          audio.remove  if audio
          Ffmprb.logger.debug "Removed sample files"
        rescue => e
          Ffmprb.logger.error "Error removing sample files: #{e.message}"
        end
      end
    end

    # Manipulation

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
        raise Error.new "'#{path}' is un#{@mode.to_s[0..3]}able"  unless path && !path.empty?
      end
    end

    def probe(force=false)
      return @probe  unless !@probe || force
      cmd = " -v quiet -i #{path} -print_format json -show_format -show_streams"
      cmd << " -show_frames"  if force
      @probe = JSON.parse(Util::ffprobe cmd).tap do |probe|
        raise Error.new "This doesn't look like a ffprobable file"  unless probe['streams']
      end
    end

  end

end

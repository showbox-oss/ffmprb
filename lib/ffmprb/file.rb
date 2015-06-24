require 'json'
require 'tempfile'

module Ffmprb

  class File

    def self.open(path)
      new path: (path.respond_to?(:path)? path.path : path), mode: :read
    end

    def self.create(path)
      new path: path, mode: :write
    end

    def self.temp(extname)
      file = create(Tempfile.new(['', extname]).tap{|tf| tf.close}.path)

      return file  unless block_given?

      begin
        yield file
      ensure
        FileUtils.remove_entry file.path
      end
    end

    def initialize(path:, mode:)
      @path = path
      @mode = mode.to_sym
      raise Error.new "Open for read, create for write, ??? for #{@mode}"  unless %i[read write].include?(@mode)
      test_path!
    end

    def path
      test_path!
      @path
    end

    def extname
      ::File.extname path
    end

    # Info

    def length
      probe['duration'].to_f
    end

    def resolution
      "#{probe['width']}x#{probe['height']}"
    end


    def snap_shot(  # NOTE can snap output (an image) or audio (a sound) or both
      at: 0.01,
      output: nil,
      audio: nil
    )
      audio = File.temp('.mp3')  if audio == true
      output = File.temp('.jpg')  unless audio && !block_given?

      raise Error.new "Incorrect output extname (must be .jpg)"  unless output.extname =~ /jpe?g$/
      raise Error.new "Incorrect audio extname (must be .mp3)"  unless !audio || audio.extname =~ /mp3$/
      raise Error.new "Can only take either output OR audio unless a block is given"  unless block_given? || (!!audio ^ !!output)

      cmd = " -i #{path}"
      cmd << " -deinterlace -an -ss #{at} -r 1 -vcodec mjpeg -f mjpeg #{output.path}"  if output
      cmd << " -vn -ss #{at} -t 1 -f mp3 #{audio.path}"  if audio
      Ffmprb::Util.ffmpeg cmd

      return output || audio  unless block_given?

      begin
        yield *[output, audio].compact
      ensure
        output.remove  if output
        audio.remove  if audio
      end
    end

    # Manipulation

    def remove
      FileUtils.remove_entry path
      @path = nil
    end

    private

    def test_path!
      # XXX ensure readabilty/writability/readiness
      raise Error.new "'#{@path}' is un#{@mode.to_s[0..3]}able"  unless @path && !@path.empty?
    end

    def probe
      test_path!
      @probe ||=
        begin
          streams = JSON.parse(
            ff = Util::ffprobe(" -v quiet -i #{@path} -print_format json -show_format -show_streams")
          )['streams']

          raise Error.new "This doesn't look like a ffprobable file"  unless streams
          streams.first
        end
    end

  end

end

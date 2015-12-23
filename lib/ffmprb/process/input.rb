module Ffmprb

  class Process

    class Input

      class << self

        def resolve(io)
          return io  unless io.is_a? String  # XXX XXX

          File.open(io).tap do |file|
            Ffmprb.logger.warn "Input file does no exist (#{file.path}), will probably fail"  unless file.exist?
          end
        end

        # XXX check for unknown options

        def video_args(video=nil)
          video = Process.input_video_options.merge(video.to_h)
          [].tap do |args|
            fps = nil  # NOTE ah, ruby
            args.concat %W[-noautorotate]  unless video.delete(:auto_rotate)
            args.concat %W[-r #{fps}]  if (fps = video.delete(:fps))
            fail "Unknown input video options: #{video}"  unless video.empty?
          end
        end

        def audio_args(audio=nil)
          audio = Process.input_audio_options.merge(audio.to_h)
          [].tap do |args|
            fail "Unknown input audio options: #{audio}"  unless audio.empty?
          end
        end

      end

      attr_accessor :io
      attr_reader :process

      def initialize(io, process, video:, audio:)
        @io = self.class.resolve(io)
        @process = process
        @channels = {
          video: video && @io.channel?(:video) && OpenStruct.new(video),
          audio: audio && @io.channel?(:audio) && OpenStruct.new(audio)
        }
      end


      def copy(input)
        input.chain_copy self
      end


      def args
        [].tap do |args|
          args.concat self.class.video_args(channel :video)  if channel? :video
          args.concat self.class.audio_args(channel :audio)  if channel? :audio
          args.concat ['-i', io.path]
        end
      end

      def filters_for(lbl, video:, audio:)
        in_lbl = process.input_label(self)
        [
          *(if video && channel?(:video)
              if video.resolution && video.fps
                Filter.scale_pad_fps video.resolution, video.fps, "#{in_lbl}:v", "#{lbl}:v"
              elsif video.resolution
                Filter.scale_pad video.resolution, "#{in_lbl}:v", "#{lbl}:v"
              elsif video.fps
                Filter.fps video.fps, "#{in_lbl}:v", "#{lbl}:v"
              else
                Filter.copy "#{in_lbl}:v", "#{lbl}:v"
              end
            end),
          *(audio && channel?(:audio)? Filter.anull("#{in_lbl}:a", "#{lbl}:a"): nil)
        ]
      end

      def channel?(medium)
        io.channel? medium
      end

      def channel(medium)
        @channels[medium]
      end


      def chain_copy(src_input)
        src_input
      end

    end

  end

end

require_relative 'input/chain_base'
require_relative 'input/channeled'
require_relative 'input/cropped'
require_relative 'input/cut'
require_relative 'input/looping'
require_relative 'input/loud'
require_relative 'input/temp'

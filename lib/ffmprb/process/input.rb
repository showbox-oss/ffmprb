module Ffmprb

  class Process

    class Input

      class << self

        def resolve(io)
          return io  unless io.is_a? String

          case io
          when /^\/\w/
            File.open(io).tap do |file|
              Ffmprb.logger.warn "Input file does no exist (#{file.path}), will probably fail"  unless file.exist?
            end
          else
            fail Error, "Cannot resolve input: #{io}"
          end
        end

      end

      attr_accessor :io
      attr_reader :process

      def initialize(io, process, **opts)
        @io = self.class.resolve(io)
        @process = process
        @opts = opts
      end


      def copy(input)
        input.chain_copy self
      end


      def options
        opts = []
        @opts.map do |name, value|
          next  unless value
          opts << "-#{name}"
          opts << value  unless value == true
        end
        opts << '-i' << io.path
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

module Ffmprb

  class Process

    class Input

      def loop(times=31)
        Looping.new self, times
      end

      class Looping < ChainBase

        attr_reader :times

        def initialize(unfiltered, times)
          super unfiltered
          @times = times

          @raw = unfiltered
          @raw = @raw.unfiltered  while @raw.respond_to? :unfiltered
          @src_io = @raw.io
          @raw.temporise!
          @aux_input = @raw.process.temp_input(@src_io.extname)
        end

        def filters_for(lbl, video:, audio:)

          # Looping

          loop_unfiltered(video: video, audio: audio).filters_for lbl,
            video: OpenStruct.new, audio: OpenStruct.new  # NOTE the processing is done before looping
        end

        protected

        def loop_unfiltered(video:, audio:)
          fail Error, "Double looping is not supported... yet"  unless @src_io  # TODO video & audio params check
          src_io = @src_io
          @src_io = nil

          Ffmprb.logger.debug "Validating limitations..."

          raw = unfiltered
          raw = raw.unfiltered  while raw.respond_to? :unfiltered
          fail Error, "Something is wrong (double looping?)"  unless raw == @raw

          dst_io = File.temp_fifo(src_io.extname)

          buff_raw_io = File.temp_fifo(src_io.extname)
          Util::ThreadedIoBuffer.new(
            File.async_opener(buff_raw_io, 'r'),
            File.async_opener(raw.io, 'w')
          )

          Ffmprb.logger.debug "Preprocessed looping input will be #{dst_io.path} and raw input copy will go through #{buff_raw_io.path} to #{raw.io.path}..."

          Util::Thread.new "looping input processor" do
            Ffmprb.logger.debug "Processing before looping"

            process = Process.new
            in1 = process.input(src_io)
            process.output(dst_io, video: video, audio: audio).
              lay in1.copy(unfiltered)
            process.output(buff_raw_io,
              video: OpenStruct.new, audio: OpenStruct.new  # NOTE raw input copy
            ).
              lay in1
            process.run  # TODO limit:

          end

          buff_ios = (0..times).map{File.temp_fifo src_io.extname}
          Ffmprb.logger.debug "Preprocessed #{dst_io.path} will be teed to #{buff_ios.map(&:path).join '; '}"
          Util::ThreadedIoBuffer.new(
            File.async_opener(dst_io, 'r'),
            *buff_ios.map{|io| File.async_opener io, 'w'}
          )

          Ffmprb.logger.debug "Concatenation of #{buff_ios.map(&:path).join '; '} will go to #{@aux_input.io.path} to be fed to this process"

          Util::Thread.new "looper" do
            Ffmprb.logger.debug "Looping #{buff_ios.size} times"

            process = Process.new(ignore_broken_pipe: true)  # NOTE may not write its entire output, it's ok
            ins = buff_ios.map{|i| process.input i}
            process.output(@aux_input.io, video: nil, audio: nil) do
              ins.each{|i| lay i}
            end
            process.run  # TODO limit:

          end

          self.unfiltered = @aux_input
        end

      end

    end

  end

end

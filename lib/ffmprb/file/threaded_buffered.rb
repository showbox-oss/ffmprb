module Ffmprb

  class File  # NOTE I would rather rename it to Stream at the moment

    class << self

      def threaded_buffered_fifo(extname='.tmp')
        input_fifo_file = temp_fifo(extname)
        output_fifo_file = temp_fifo(extname)
        Ffmprb.logger.debug "Opening #{input_fifo_file.path}>#{output_fifo_file.path} for buffering"
        Util::Thread.new do
          begin
            Util::ThreadedIoBuffer.new opener(input_fifo_file, 'r'), opener(output_fifo_file, 'w')
            Util::Thread.join_children!
            Ffmprb.logger.debug "IoBuffering from #{input_fifo_file.path} to #{output_fifo_file.path} ended"
          ensure
            input_fifo_file.unlink  if input_fifo_file
            output_fifo_file.unlink  if output_fifo_file
          end
        end
        Ffmprb.logger.debug "IoBuffering from #{input_fifo_file.path} to #{output_fifo_file.path} started"

        # TODO yield buff  if block_given?

        [input_fifo_file, output_fifo_file]
      end

    end

    def threaded_buffered_copy_to(*dsts)
      Util::ThreadedIoBuffer.new(
        self.class.opener(self, 'r'),
        *dsts.map{|io| self.class.opener io, 'w'}
      )
    end

  end

end

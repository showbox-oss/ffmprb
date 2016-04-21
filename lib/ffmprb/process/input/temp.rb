module Ffmprb

  class Process

    class Input

      def temporise_io!(extname=nil)
        @io.tap do
          @io = File.temp_fifo(extname || io.extname)
        end
      end

    end

  end

end

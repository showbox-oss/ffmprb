module Ffmprb

  class Process

    class Input

      def temporise_io!(extname=nil)
        process.proc_vis_edge @io, process, :remove
        @io.tap do
          @io = File.temp_fifo(extname || io.extname)
          process.proc_vis_edge @io, process
        end
      end

    end

  end

end

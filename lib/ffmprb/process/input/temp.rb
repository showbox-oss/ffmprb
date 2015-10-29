module Ffmprb

  class Process

    class Input

      def temporise!(extname=nil)
        extname ||= io.extname
        self.io = nil
        extend Temp
        @extname = extname
      end

      module Temp

        def io
          @io ||= File.temp_fifo(@extname)
        end

      end

    end

  end

end

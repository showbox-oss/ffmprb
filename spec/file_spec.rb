require 'mkfifo'

TST_STR_6K = 'Roger?' * 1024

describe Ffmprb::File do

  context "buffered fifos" do

    around do |example|
      Ffmprb::Util::ThreadedIoBuffer.block_size.tap do |default|
        begin
          Ffmprb::Util::ThreadedIoBuffer.block_size = 1024
          example.run
        ensure
          Ffmprb::Util::ThreadedIoBuffer.block_size = default
        end
      end
    end

    around do |example|
      Ffmprb::Util::Thread.new "test" do
        @fifo = Ffmprb::File.threaded_buffered_fifo '.ext'
        example.run
        Ffmprb::Util::Thread.join_children!
      end.join
    end

    it "should have the destination readable (while writing to)" do

      # piggy-backing another test
      expect(@fifo[0].extname).to eq '.ext'
      expect(@fifo[1].extname).to eq '.ext'

      Timeout.timeout(4) do
        file_out = File.open(@fifo[0].path, 'w')
        file_in = File.open(@fifo[1].path, 'r')

        writer = Thread.new do
          512.times do
            file_out.write(TST_STR_6K)
          end
          file_out.close
        end

        reader = Thread.new do
          512.times do
            expect(file_in.read(TST_STR_6K.length)).to eq TST_STR_6K
          end
          expect(file_in.read 1).to eq nil  # EOF
          file_in.close
        end

        writer.join
        reader.join
      end
    end

    it "should not timeout if the reader is a bit slow" do
      Ffmprb::Util::ThreadedIoBuffer.timeout.tap do |timeout|
        begin
          Ffmprb::Util::ThreadedIoBuffer.timeout = 2

          File.open(@fifo[0].path, 'w') do |file_out|
            File.open(@fifo[1].path, 'r') do |file_in|
              Timeout.timeout(5) do
                thr = Thread.new do
                  file_out.write(TST_STR_6K * 512)
                  file_out.close
                end
                sleep 1
                expect(file_in.read(TST_STR_6K.length * 512 + 1)).to eq TST_STR_6K * 512
                thr.join
                Ffmprb::Util::Thread.join_children!
              end
            end
          end
        ensure
          Ffmprb::Util::ThreadedIoBuffer.timeout = timeout
        end
      end
    end

    it "should timeout if the reader is very slow" do
      Ffmprb::Util::ThreadedIoBuffer.timeout.tap do |timeout|
        begin
          Ffmprb::Util::ThreadedIoBuffer.timeout = 1

          File.open(@fifo[0].path, 'w') do |file_out|
            File.open(@fifo[1].path, 'r') do |file_in|
              Timeout.timeout(2) do
                expect{
                  file_out.write(TST_STR_6K * 1024)
                }.to raise_error Errno::EPIPE
              end
            end
          end
          expect{Ffmprb::Util::Thread.join_children!}.to raise_error Ffmprb::Error
        ensure
          Ffmprb::Util::ThreadedIoBuffer.timeout = timeout
        end
      end
    end

    it "should be writable (before the destination is ever read), up to the buffer size(1024*1024)" do
      Timeout.timeout(2) do
        file_out = File.open(@fifo[0].path, 'w')
        file_in = File.open(@fifo[1].path, 'r')
        file_out.write(TST_STR_6K * 64)
        file_out.close
        expect(file_in.read(TST_STR_6K.length * 64 + 1)).to eq TST_STR_6K * 64
        file_in.close
      end
    end

  end

end

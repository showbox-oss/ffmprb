require 'mkfifo'

TST_STR_6K = 'Roger?' * 1024

describe Ffmprb::File do

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

  it "should wrap ruby Files"

  context "simple buffered fifos" do

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
            expect(file_in.read(6*1024) == TST_STR_6K).to be_truthy
          end
          expect(file_in.read 1).to eq nil  # EOF
          file_in.close
        end

        writer.join
        reader.join
      end
    end

    it "should not timeout if the reader is a bit slow" do
      Ffmprb::Util::ThreadedIoBuffer.timeout_limit.tap do |default|
        begin
          Ffmprb::Util::ThreadedIoBuffer.timeout_limit = 2

          File.open(@fifo[0].path, 'w') do |file_out|
            File.open(@fifo[1].path, 'r') do |file_in|
              Timeout.timeout(8) do
                thr = Thread.new do
                  file_out.write(TST_STR_6K * 512)
                  file_out.close
                end
                sleep 1
                expect(file_in.read == TST_STR_6K * 512).to be_truthy
                thr.join
                Ffmprb::Util::Thread.join_children!
              end
            end
          end
        ensure
          Ffmprb::Util::ThreadedIoBuffer.timeout_limit = default
        end
      end
    end

    it "should timeout if the reader is very slow" do
      Ffmprb::Util::ThreadedIoBuffer.timeout_limit.tap do |default|
        begin
          Ffmprb::Util::ThreadedIoBuffer.timeout_limit = 2

          File.open(@fifo[0].path, 'w') do |file_out|
            File.open(@fifo[1].path, 'r') do |file_in|
              Timeout.timeout(8) do
                expect{
                  file_out.write(TST_STR_6K * 1024)
                }.to raise_error Errno::EPIPE
              end
            end
          end
          expect{
            Ffmprb::Util::Thread.join_children!
          }.to raise_error Ffmprb::Error
        ensure
          Ffmprb::Util::ThreadedIoBuffer.timeout_limit = default
        end
      end
    end

    it "should be writable (before the destination is ever read), up to the buffer size(1024*1024)" do
      Timeout.timeout(2) do
        file_out = File.open(@fifo[0].path, 'w')
        file_in = File.open(@fifo[1].path, 'r')
        file_out.write(TST_STR_6K * 64)
        file_out.close
        expect(file_in.read == TST_STR_6K * 64).to be_truthy
        file_in.close
      end
    end

    it "should break the writer if the reader is broken" do
      Timeout.timeout(2) do
        file_out = File.open(@fifo[0].path, 'w')
        file_in = File.open(@fifo[1].path, 'r')
        thr = Thread.new do
          begin
            file_in.read(64)
          ensure
            file_in.close
          end
        end
        expect {
          begin
            file_out.write(TST_STR_6K * 1024)
          ensure
            file_out.close
          end
        }.to raise_error Errno::EPIPE
        thr.join
      end
    end

  end

  context "N-Tee buffering" do

    around do |example|
      temp_fifos = []
      temp_fifos << @master_fifo = Ffmprb::File.temp_fifo
      temp_fifos << @copy_fifo1 = Ffmprb::File.temp_fifo
      temp_fifos << @copy_fifo2 = Ffmprb::File.temp_fifo
      temp_fifos << @copy_fifo3 = Ffmprb::File.temp_fifo

      begin
        example.run
      ensure
        temp_fifos.each &:unlink
      end
    end

    it "should feed readers everything the writer has written" do
      Timeout.timeout(15) do
        thrs = []
        thrs << Thread.new do
          File.open @copy_fifo1.path, 'r' do |file|
            expect(file.read(6*1024) == TST_STR_6K).to be_truthy
          end
        end
        thrs << Thread.new do
          File.open @copy_fifo2.path, 'r' do |file|
            512.times {
              expect(file.read(6*1024) == TST_STR_6K).to be_truthy
              sleep 0.001
            }
          end
        end
        thrs << Thread.new do
          sleep 1
          File.open @copy_fifo3.path, 'r' do |file|
            expect(file.read == TST_STR_6K * 1024).to be_truthy
          end
        end

        @master_fifo.threaded_buffered_copy_to @copy_fifo1, @copy_fifo2, @copy_fifo3

        File.open @master_fifo.path, 'w' do |file|
          file.write TST_STR_6K * 1024
        end

        thrs.each &:join
      end
    end

    it "should pass on closed readers" do
      Timeout.timeout(15) do
        thrs = []
        thrs << Thread.new do
          File.open @copy_fifo1.path, 'r' do |file|
            file.read 64
          end
        end
        thrs << Thread.new do
          File.open @copy_fifo2.path, 'r' do |file|
            1024.times {
              file.read 1024
              sleep 0.001
            }
          end
          File.open @copy_fifo3.path, 'r' do |file|
            expect(file.read == TST_STR_6K * 1024).to be_truthy
          end
        end

        @master_fifo.threaded_buffered_copy_to @copy_fifo1, @copy_fifo2, @copy_fifo3

        File.open @master_fifo.path, 'w' do |file|
          file.write(TST_STR_6K * 1024)
        end

        thrs.each &:join
      end
    end

    it "should terminate once all readers are done or broken" do
      Timeout.timeout(15) do
        thrs = []
        thrs << Thread.new do
          File.open @copy_fifo1.path, 'r' do |file|
            file.read 64
          end
        end
        thrs << Thread.new do
          File.open @copy_fifo2.path, 'r' do |file|
            1024.times { |i|
              expect(file.read(1024).length).to eq 1024
              sleep 0.001
            }
          end
          File.open @copy_fifo3.path, 'r' do |file|
            file.read 64
          end
        end

        @master_fifo.threaded_buffered_copy_to @copy_fifo1, @copy_fifo2, @copy_fifo3

        expect {
          File.open @master_fifo.path, 'w' do |file|
            i = file.write(TST_STR_6K * 1024)
          end
        }.to raise_error Errno::EPIPE

        thrs.each &:join
      end
    end

  end

end

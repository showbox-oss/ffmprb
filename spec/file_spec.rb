require 'mkfifo'

TST_STR_6K = 'Roger?' * 1024

describe Ffmprb::File do

  context 'fifos' do

    context :buffered_fifo_to do

      around do |example|
        Dir.mktmpdir do |dir|
          sink = File.join(dir, 'sink.ext')
          File.mkfifo(sink)
          begin
            @sink_file = Ffmprb::File.create(sink)
            @buff_file = @sink_file.buffered_fifo_to

            example.run
          ensure
            @sink_file.remove  rescue nil
            @buff_file.remove  rescue nil
          end
        end
      end

      it "should have the same extname" do
        expect(@buff_file.extname).to eq @sink_file.extname
      end

      it "should be writable (before the destination is ever read), up to the buffer size (1024*1024)" do
        Timeout::timeout(2) do
          file_out = File.open(@buff_file.path, 'w')
          file_in = File.open(@sink_file.path, 'r')
          file_out.write(TST_STR_6K * 64)
          file_out.close
          expect(file_in.read(TST_STR_6K.length * 64)).to eq TST_STR_6K * 64
          file_in.close
        end
      end

      it "should has the destination readable (while writing to)" do
        Timeout::timeout(4) do
          file_out = File.open(@buff_file.path, 'w')
          file_in = File.open(@sink_file.path, 'r')

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

    end


    context :buffered_fifos do

      let(:fifos) {Ffmprb::File.buffered_fifos '.ext'}

      after do
        fifos.each &:remove
      end

      it "should have the given extname" do
        expect(fifos[0].extname).to eq '.ext'
        expect(fifos[1].extname).to eq '.ext'
      end

      it "should not timeout if the reader is a bit slow" do
        Ffmprb::Util::Buffer.default_timeout.tap do |default_timeout|
          Ffmprb::Util::Buffer.default_timeout = 2

          File.open(fifos[0].path, 'w') do |file_out|
            File.open(fifos[1].path, 'r') do |file_in|
              Timeout::timeout(5) do
                thr = Thread.new do
                  file_out.write(TST_STR_6K * 512)
                  file_out.close
                end
                sleep 1
                expect(file_in.read(TST_STR_6K.length * 512 + 1)).to eq TST_STR_6K * 512
                thr.join
              end
            end
          end

          Ffmprb::Util::Buffer.default_timeout = default_timeout
        end
      end

      it "should timeout if the reader is very slow" do
        Ffmprb::Util::Buffer.default_timeout.tap do |default_timeout|
          Ffmprb::Util::Buffer.default_timeout = 1

          File.open(fifos[0].path, 'w') do |file_out|
            File.open(fifos[1].path, 'r') do |file_in|
              Timeout::timeout(2) do
                expect{
                  file_out.write(TST_STR_6K * 1024)
                }.to raise_error Errno::EPIPE
              end
            end
          end

          Ffmprb::Util::Buffer.default_timeout = default_timeout
        end
      end

      it "should be writable (before the destination is ever read), up to the buffer size(1024*1024)" do
        Timeout::timeout(2) do
          file_out = File.open(fifos[0].path, 'w')
          file_in = File.open(fifos[1].path, 'r')
          file_out.write(TST_STR_6K * 64)
          file_out.close
          expect(file_in.read(TST_STR_6K.length * 64 + 1)).to eq TST_STR_6K * 64
          file_in.close
        end
      end

      it "should has the destination readable (while writing to)" do
        Timeout::timeout(4) do
          file_out = File.open(fifos[0].path, 'w')
          file_in = File.open(fifos[1].path, 'r')

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

    end

  end

end

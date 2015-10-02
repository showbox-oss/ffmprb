class StamError < RuntimeError; end

describe Ffmprb::Util::Thread do

  describe 'timeout_or_live' do

    it "should act normal under normal circumstances" do
      q = Queue.new
      Thread.new do
        sleep 0.5
        q.enq "OK"
      end
      thr = Ffmprb::Util::Thread.new do
        Ffmprb::Util::Thread.timeout_or_live(1, timeout: 0.25) do
          q.deq
        end
      end
      Timeout.timeout(0.9) do
        expect(thr.value).to eq "OK"
      end
    end

    it "should supply a thread with means to time out" do
      q = Queue.new
      Thread.new do
        sleep 1.5
        q.enq "OK"
      end
      thr = Ffmprb::Util::Thread.new do
        Ffmprb::Util::Thread.timeout_or_live(1, timeout: 0.25) do
          q.deq
        end
      end
      Timeout.timeout 1.1 do
        expect{thr.value}.to raise_error Ffmprb::Util::TimeLimitError
      end
    end

    it "should supply a thread with means to bail out" do
      q = Queue.new
      Thread.new do
        sleep 1.5
        q.enq "OK"
      end
      thr = Ffmprb::Util::Thread.new do
        Ffmprb::Util::Thread.timeout_or_live(timeout: 0.25) do |time|
          fail StamError  if time > 1
          q.deq
        end
      end
      Timeout.timeout 1.1 do
        expect{thr.value}.to raise_error StamError
      end
    end

    it "should fail a thread when its (any) parent dies (tragically)" do
      in_thr = nil
      thr = Thread.new do
        in_thr = Ffmprb::Util::Thread.new "inner" do
          Ffmprb::Util::Thread.timeout_or_live(timeout: 0.5) do
            sleep 1
          end
          "OK"
        end
        fail StamError
      end
      Timeout.timeout 0.1 do  # just to be sure thr is ended
        expect{thr.join}.to raise_error StamError
      end
      expect(in_thr).to be_alive
      Timeout.timeout 0.9 do
        expect{in_thr.value}.to raise_error Ffmprb::Util::Thread::ParentError
      end
    end

  end

  describe 'join_children!' do

    it "should 'release' a thread when its sibling dies (tragically)" do
      Ffmprb::Util::Thread.timeout.tap do |timeout|
        Ffmprb::Util::Thread.timeout = 0.5

        in_thr = nil
        thr = Ffmprb::Util::Thread.new "main" do
          in_thr = Ffmprb::Util::Thread.new "sib1" do
            Ffmprb::Util::Thread.timeout_or_live(timeout: 0.5) do |time|
              sleep 1
            end
            "OK"
          end
          Ffmprb::Util::Thread.new "sib2" do
            fail StamError
          end
          Ffmprb::Util::Thread.join_children!
        end

        Timeout.timeout 0.9 do  # just to be sure thr is ended
          expect{thr.join}.to raise_error StamError
        end
        expect(in_thr).to be_alive
        Timeout.timeout 1.1 do
          expect{in_thr.join}.to raise_error Ffmprb::Util::Thread::ParentError
        end

        Ffmprb::Util::Thread.timeout = timeout
      end
    end

  end

end

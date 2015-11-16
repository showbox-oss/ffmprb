require 'rmagick'
require 'sox'

MIN_VOLUME = -0xFFFF

describe Ffmprb do


  it 'has a version number' do
    expect(Ffmprb::VERSION).not_to be nil
  end

  # IMPORTANT NOTE Examples here use static (pre-generated) sample files, but the interface is streaming-oriented
  # So there's just a hope it all works well with streams, which really must be replaced by appropriate specs

  context :process do

    around do |example|
      Ffmprb::File.temp('.mp4') do |tf|
        @av_out_file = tf
        Ffmprb::File.temp('.flv') do |tf|
          @av_out_stream = tf
          Ffmprb::File.temp('.mp3') do |tf|
            @a_out_file = tf
            example.run
          end
        end
      end
    end

    def check_av_c_gor_at!(at, file: @av_out_file)
      file.sample at: at do |shot, sound|
        check_reddish! pixel_data(shot, 250, 10)
        check_greenish! pixel_data(shot, 250, 110)
        check_note! :C6, wave_data(sound)
      end
    end

    def check_av_e_bow_at!(at)
      @av_out_file.sample at: at do |shot, sound|
        check_white! pixel_data(shot, 250, 10)
        check_black! pixel_data(shot, 250, 110)
        check_note! :E6, wave_data(sound)
      end
    end

    def check_av_btn_wtb_at!(at, black: false)
      @av_out_file.sample at: at do |shot, sound|
        pixel = pixel_data(shot, 250, 110)
        wave = wave_data(sound)
        if black
          check_black! pixel
          expect(wave.volume).to eq MIN_VOLUME
        else
          check_white! pixel
          check_note! :B6, wave
          expect(wave.volume).to be > MIN_VOLUME
        end
      end
    end

    def check_black!(pixel)
      expect(channel_max pixel).to eq 0
    end

    def check_white!(pixel)
      expect(channel_min pixel).to eq 0xFFFF
    end

    def check_greenish!(pixel)
      expect(pixel.green).to be > pixel.red
      expect(pixel.green).to be > pixel.blue
      expect(2 * (pixel.red - pixel.blue).abs).to be < (pixel.green - pixel.blue).abs
      expect(2 * (pixel.red - pixel.blue).abs).to be < (pixel.green - pixel.red).abs
    end

    def check_reddish!(pixel)
      expect(pixel.red).to be > pixel.green
      expect(pixel.red).to be > pixel.blue
      expect(2 * (pixel.green - pixel.blue).abs).to be < (pixel.red - pixel.blue).abs
      expect(2 * (pixel.green - pixel.blue).abs).to be < (pixel.red - pixel.green).abs
    end

    def check_note!(note, wave)
      expect(wave.frequency).to be_approximately NOTES[note]
    end


    it "should transcode" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, video: {resolution: Ffmprb::HD_720p, fps: 30}) do
          roll in1
        end

      end

      check_av_c_gor_at! 1
      expect(@av_out_file.resolution).to eq Ffmprb::HD_720p
      expect(@av_out_file.length).to be_approximately 9
    end

    it "should transcode video (no audio) with defaults" do
      Ffmprb::File.temp_fifo '.apng' do |tmp_papng|

        Thread.new do
          Ffmprb::Util.ffmpeg '-filter_complex', 'testsrc=d=2:r=25', tmp_papng.path
        end

        Ffmprb.process(@av_out_file) do |file_output|

          in1 = input(tmp_papng, default_fps: 25)
          output(file_output, audio: false) do  # XXX
            roll in1
          end

        end

        expect(@av_out_file.length).to be_approximately 2

      end
    end

    it "should partially support multiple outputs" do
      Ffmprb::File.temp('.mp4') do |another_av_out_file|
        Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output1|

          in1 = input(file_input)
          output(file_output1, video: {resolution: Ffmprb::HD_720p, fps: 30}) do
            roll in1.cut(to: 6)
          end
          output(another_av_out_file, video: {resolution: Ffmprb::HD_720p, fps: 30}) do
            roll in1
          end

        end

        check_av_c_gor_at! 1
        check_av_c_gor_at! 1, file: another_av_out_file
        expect(@av_out_file.resolution).to eq Ffmprb::HD_720p
        expect(another_av_out_file.resolution).to eq Ffmprb::HD_720p
        expect(@av_out_file.length).to be_approximately 6
        expect(another_av_out_file.length).to be_approximately 9
      end
    end

    it "should ignore broken pipes (or not)" do
      [:to, :not_to].each do |to_not_to|
        Ffmprb::File.temp_fifo('.flv') do |av_pipe|
          Thread.new do
            begin
              tmp = File.open(av_pipe.path, 'r')
              tmp.read(1)
            ensure
              tmp.close  if tmp
            end
          end

          expect do
            Ffmprb.process(@av_file_e_bow_9, ignore_broken_pipe: to_not_to == :not_to) do |file_input|

              in1 = input(file_input)
              output(av_pipe, video: {resolution: Ffmprb::HD_1080p, fps: 60}) do
                roll in1.loop
              end

            end
          end.send to_not_to, raise_error(*(to_not_to == :to ? Ffmprb::Error : nil))
        end
      end
    end

    it "should parse path arguments (and transcode)" do
      Ffmprb.process(@av_file_e_bow_9.path, @av_out_file.path) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1
        end

      end

      check_av_e_bow_at! 1
      expect(@av_out_file.resolution).to eq Ffmprb::CGA
      expect(@av_out_file.length).to be_approximately 9
    end

    it "should concat" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1
          roll in1
        end

      end

      check_av_c_gor_at! 2
      check_av_c_gor_at! 8
      expect(@av_out_file.length).to be_approximately 18
    end

    # TODO doesn't work with non-streaming files...
    it "should loop" do
      Ffmprb.process(@av_file_btn_wtb_16, @av_out_stream) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1
        end

      end

      expect(@av_out_stream.length).to be_approximately 16

      Ffmprb.process(@av_out_stream, @av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1.cut(to: 12).loop.cut(to: 47)
        end

      end

      check_av_btn_wtb_at! 2
      check_av_btn_wtb_at! 6, black: true
      check_av_btn_wtb_at! 10
      check_av_btn_wtb_at! 14
      check_av_btn_wtb_at! 18, black: true
      check_av_btn_wtb_at! 45

      expect(@av_out_file.length).to be_approximately 47
    end

    it "should roll reels after specific time (cutting previous reels)" do
      Ffmprb.process(@av_file_c_gor_9, @av_file_btn_wtb_16, @av_out_file) do |file_input, file_input_2, file_output|

        in1 = input(file_input)
        in2 = input(file_input_2)
        output(file_output) do
          roll in1
          roll in2, after: 3
        end

      end

      check_av_c_gor_at! 2
      check_av_btn_wtb_at! 4
      expect(@av_out_file.length).to be_approximately 19
    end

    it "should roll reels after specific time (even the first one, adding blanks in the beginning)" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1, after: 3
        end

      end

      check_av_c_gor_at! 4
      expect(@av_out_file.length).to be_approximately 12
    end


    [12, 21].each do |duration|
      it "should cut to precise duration (total 12 <=> cut after #{duration})" do
        Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output|

          in1 = input(file_input)
          output(file_output) do
            roll in1
            roll in1.cut to: (duration - file_input.length)
          end

        end

        check_av_c_gor_at! 5
        check_av_c_gor_at! 7
        expect(@av_out_file.length).to be_approximately duration
      end
    end

    it "should crop segments" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1.crop(0.25)
          roll in1
          roll in1.crop(width: 0.25, height: 0.25)
          roll in1.crop(left: 0, top: 0, width: 0.25, height: 0.25)
        end

      end

      @av_out_file.sample at: 5 do |snap, sound|
        check_greenish! pixel_data(snap, 100, 10)
        check_note! :C6, wave_data(sound)
      end
      check_av_c_gor_at! 14
      @av_out_file.sample at: 23 do |snap, sound|
        check_greenish! pixel_data(snap, 100, 10)
        check_note! :C6, wave_data(sound)
      end
      @av_out_file.sample at: 32 do |snap, sound|
        check_reddish! pixel_data(snap, 100, 10)
        check_note! :C6, wave_data(sound)
      end
    end

    it "should cut and crop segments" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1.crop(0.25).cut(to: 3)
          roll in1
        end

      end

      @av_out_file.sample at: 2 do |snap, sound|
        check_greenish! pixel_data(snap, 100, 10)
        check_note! :C6, wave_data(sound)
      end
      check_av_c_gor_at! 4
      expect(@av_out_file.length).to be_approximately 12
    end

    # TODO might be insufficient
    it "should cut segments in any order" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output) do
          roll in1.cut(from: 1)
          roll in1.crop(0.25).cut(to: 5)
        end

      end

      check_av_c_gor_at! 1
      @av_out_file.sample at: 9 do |snap, sound|
        check_greenish! pixel_data(snap, 100, 10)
        check_note! :C6, wave_data(sound)
      end
      expect(@av_out_file.length).to be_approximately 13
    end

    it "should change volume and mute" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |av_i, av_o|
        in1 = input(av_i)
        output(av_o) do
          roll in1.cut(to: 4)
          roll in1.cut(to: 4).mute
          roll in1.cut(to: 4).volume(0.5)
        end
      end

      expect(
        [5, 9, 1].map{|s| wave_data(@av_out_file.sample_audio at: s).volume}
      ).to be_ascending
    end

    it "should modulate volume" do
      Ffmprb.process(@av_file_c_gor_9, @av_out_file) do |av_i, av_o|
        in1 = input(av_i)
        output(av_o) do
          roll in1.cut(to: 3)
          roll in1.volume(1.9 => 0, 4.1 => 0, 6 => 0.5, 7.9 => 1)
        end
      end

      volume_at = ->(sec){wave_data(@av_out_file.sample_audio at: sec).volume}

      expect(volume_at.call 0.1).to be_approximately volume_at.call(11)
      expect(
        [4, 3.75, 3.5].map(&volume_at)
      ).to be_ascending
      expect(volume_at.call 5).to eq volume_at.call 6
    end

    it "should detect silence and pass input to output" do
      silence = Ffmprb.find_silence(@av_file_btn_wtb_16, @av_out_file)
      expect(silence.length).to eq 2
      prev_silent_end_at = 0
      silence.each do |silent|
        @av_out_file.sample at: silent.start_at + 1 do |image, sound|
          expect(wave_data(sound).volume).to eq MIN_VOLUME
          check_black! pixel_data(image, 100, 100)
        end
        @av_out_file.sample at: (prev_silent_end_at + silent.start_at)/2 do |image, sound|
          expect(wave_data(sound).volume).to be > MIN_VOLUME
          check_white! pixel_data(image, 100, 100)
        end
        prev_silent_end_at = silent.end_at
      end
    end

    context "media" do

      let(:m_input) {{video: @v_file_6, audio: @a_file_g_16}}
      let(:m_output_extname) {{video: '.y4m', audio: '.wav'}}

      [:video, :audio].each do |medium|
        not_medium = ([:video, :audio] - [medium])[0]
        medium_params = {
          video: {},
          audio: {encoder: nil}
        }
        [
          lambda do |av_file_input, m_file_input, m_file_output|  ##1
            in1 = input(av_file_input)
            output(m_file_output, medium => medium_params[medium], not_medium => false) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##2
            in1 = input(av_file_input)
            output(m_file_output, medium => medium_params[medium]) do
              roll in1.send(medium).cut(from: 3, to: 5)
              roll in1.send(medium).cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##3
            in1 = input(av_file_input)
            output(m_file_output, medium => medium_params[medium]) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##4
            in1 = input(m_file_input)
            output(m_file_output, medium => medium_params[medium], not_medium => false) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##5
            in1 = input(m_file_input)
            output(m_file_output, medium => medium_params[medium]) do
              roll in1.send(medium).cut(from: 3, to: 5)
              roll in1.send(medium).cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##6
            in1 = input(m_file_input)
            output(m_file_output, medium => medium_params[medium]) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end
        ].each_with_index do |script, i|

          it "should work with video only and audio only, as input and as output (#{medium}##{i+1})" do

            Ffmprb::File.temp(m_output_extname[medium]) do |m_output|

              Ffmprb.process(@av_file_c_gor_9, m_input[medium], m_output, &script)

              m_output.sample at: 2.5, medium => true, ([:video, :audio] - [medium])[0] => false do |sample|
                case medium
                when :video
                  check_greenish! pixel_data(sample, 100, 100)
                when :audio
                  expect{wave_data(m_output)}.not_to raise_error  # NOTE audio format compat. check
                  check_note! (i < 3 ? :C6 : :G6), wave_data(sample)
                end
              end


              expect(m_output.length).to be_approximately 4
              expect{
                m_output.sample at: 3, ([:video, :audio] - [medium])[0] => true, medium => false
              }.to raise_error Ffmprb::Error
            end

          end

        end
      end
    end

    context "stitching" do

      it "should transition between two reels" do
        Ffmprb.process(@av_file_c_gor_9, @av_file_e_bow_9, @av_out_file) do |input1, input2, output1|

          in1, in2 = input(input1), input(input2)
          output(output1) do
            lay in1.crop(0.25), transition: {blend: 3}
            lay in2.crop(left: 0, top: 0, width: 0.1, height: 0.1).cut(to: 8), after: 6, transition: {blend: 2}
          end

        end

        last_green = nil
        last_volume = nil
        # NOTE should transition from black+silent to green+C6 in 3 secs
        times = [0.1, 1.1, 2.1, 3.1, 4.1]
        times.each do |at|
          @av_out_file.sample at: at do |snap, sound|
            pixel = pixel_data(snap, 100, 100)
            check_greenish! pixel
            if last_green
              if at == times[-1]
                expect(pixel.green).to eq last_green
              else
                expect(pixel.green).to be > last_green
              end
            end
            last_green = pixel.green

            wave = wave_data(sound)
            check_note! :C6, wave
            if last_volume
              if at == times[-1]
                expect(wave.volume).to be_approximately last_volume
              else
                expect(wave.volume).to be > last_volume
              end
            end
            last_volume = wave.volume
          end
        end

        last_red = nil
        last_frequency = nil
        # NOTE should transition from green+C6 to white+E6 in 2 secs
        times = [4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5]
        times.each do |at|
          @av_out_file.sample at: at do |snap, sound|
            pixel = pixel_data(snap, 100, 100)

            check_greenish! pixel  unless times[-2..-1].include? at
            expect(0xFFFF - pixel.red).to be_approximately (0xFFFF - pixel.blue)

            if last_red
              if times.values_at(0..2, -1).include? at
                expect(pixel.red).to eq last_red
              else
                expect(pixel.red).to be > last_red
              end
            end
            last_red = pixel.red

            wave = wave_data(sound)

            if times[0..1].include? at
              check_note! :C6, wave
            elsif times[-2..-1].include? at
              check_note! :E6, wave
            else
              expect(wave.frequency).to be > last_frequency
            end
            last_frequency = wave.frequency
          end
        end

        # NOTE should transition from white+E6 to black+silent in 2 secs
        # XXX times = [10.9, 11.9, 12.9]

        expect(@av_out_file.length).to be_approximately 14
      end

      it "should run an external effect tool for a transition"

    end

    context :audio_overlay do
      #
      # around do |example|
      #   Timeout.timeout(4) do
      #     example.run
      #   end
      # end

      it "should overlay sound with volume" do
        Ffmprb.process(@av_file_btn_wtb_16, @a_file_g_16, @av_out_file) do |input1, input2, output1|

          in1 = input(input1)
          in2 = input(input2)
          output(output1) do
            lay in1.volume(0 => 0.5, 4 => 0.5, 5 => 1)
            overlay in2.cut(to: 5).volume(2.0 => 0, 4.0 => 1)
          end

        end

        volume_first =
          wave_data(@av_out_file.sample at: 0, video: false) do |sound|
            expect(sound.frequency).to be_between NOTES.G6, NOTES.B6
            sound.volume
          end

        check_av_btn_wtb_at! 2

        wave_data(@av_out_file.sample at: 2, video: false) do |sound|
          expect(sound.frequency).to be_approximately NOTES.B6
          expect(sound.volume).to be < volume_first
        end

        wave_data(@av_out_file.sample at: 4, video: false) do |sound|
          expect(sound.frequency).to be_between NOTES.G6, NOTES.B6
          expect(sound.volume).to be_approximately volume_first
        end

        expect(
          wave_data(@av_out_file.sample at: 9, video: false).frequency
        ).to be_approximately NOTES.B6
      end

      it "should duck the overlay sound wrt the main sound" do
        # NOTE non-streaming output file requires additional development see #181845
        Ffmprb.process(@av_file_btn_wtb_16, @a_file_g_16, @av_out_stream) do |input1, input2, output1|

          in1 = input(input1)
          in2 = input(input2)
          output(output1) do
            lay in1.cut(to: 10), transition: {blend: 1}
            overlay in2.cut(from: 4).loop, duck: :audio
          end

        end

        @av_out_stream.sample at: 2 do |snap, sound|
          check_white! pixel_data(snap, 100, 100)
          expect(wave_data(sound).frequency).to be_between(NOTES.G6, NOTES.B6)
        end

        @av_out_stream.sample at: 6 do |snap, sound|
          check_black! pixel_data(snap, 100, 100)
          expect(wave_data(sound).frequency).to be_within(10).of NOTES.G6
        end

        expect(@av_out_stream.length).to be_approximately 10
      end

      it "should duck some overlay sound wrt some main sound" do
        Ffmprb::Util::ThreadedIoBuffer.block_size.tap do |block_size|
          begin
            Ffmprb::Util::ThreadedIoBuffer.block_size = 8*1024

            # NOTE non-streaming output file requires additional development see #181845
            Ffmprb.process(@a_file_g_16, @a_out_file) do |input1, output1|

              in1 = input(input1)
              output(output1) do
                roll in1.cut(from: 4, to: 12), transition: {blend: 1}
                overlay in1, duck: :audio
              end

            end

            expect(@a_out_file.length).to be_approximately(8)

            [2, 6].each do |at|
              check_note! :G6, wave_data(@a_out_file.sample_audio at: at)
            end
          ensure
            Ffmprb::Util::ThreadedIoBuffer.block_size = block_size
          end
        end
      end

    end

    context :samples do

      it "should shoot snaps"  # XXX not sure if this functionality is needed

    end

  end

  context :info do

    it "should return the length of a clip" do
      expect(@av_file_c_gor_9.length).to be_approximately 9
    end

  end

  def pixel_data(snap, x, y)
    Magick::Image.read(snap.path)[0].pixel_color(x, y)
  end

  def wave_data(sound)
    sox_info = Ffmprb::Util.sh(Sox::SOX_COMMAND, sound.path, '-n', 'stat', output: :stderr)

    OpenStruct.new.tap do |data|
      data.frequency = $1.to_f  if sox_info =~ /Rough\W+frequency:\W*([\d.]+)/
      data.frequency = 0  unless data.frequency && data.frequency > 0
      data.volume = -$1.to_f  if sox_info =~ /Volume\W+adjustment:\W*([\d.]+)/
      data.volume ||= MIN_VOLUME
    end
  end

  def channel_min(pixel)
    [pixel.red, pixel.green, pixel.blue].min
  end

  def channel_max(pixel)
    [pixel.red, pixel.green, pixel.blue].max
  end

end

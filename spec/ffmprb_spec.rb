require 'ostruct'

require 'rmagick'
require 'sox'


describe Ffmprb do

  NOTES = OpenStruct.new(
    C6: 1046.50,
    D6: 1174.66,
    E6: 1318.51,
    F6: 1396.91,
    G6: 1567.98,
    A6: 1760.00,
    B6: 1975.53
  )


  it 'has a version number' do
    expect(Ffmprb::VERSION).not_to be nil
  end

  context :process do

    let(:a_out_extname) {'.mp3'}
    let(:output_extname) {'.mp4'}
    let(:stream_output_extname) {'.flv'}

    around do |example|
      Ffmprb::File.temp(output_extname) do |tf|
        @av_out_file = tf
        Ffmprb::File.temp(stream_output_extname) do |tf|
          @stream_av_out_file = tf
          Ffmprb::File.temp(a_out_extname) do |tf|
            @a_out_file = tf
            example.run
          end
        end
      end
    end

    let(:a_out_file) {@a_out_file}
    let(:av_out_file) {@av_out_file}
    let(:stream_av_out_file) {@stream_av_out_file}

    it "should transcode" do
      Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1
        end

      end

      expect(av_out_file.resolution).to eq Ffmprb::QVGA
      expect(av_out_file.length).to be_approximately 6
    end

    it "should parse path arguments (and transcode)" do
      Ffmprb.process(@av_file_gor.path, av_out_file.path) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1
        end

      end

      expect(av_out_file.resolution).to eq Ffmprb::QVGA
      expect(av_out_file.length).to be_approximately 6
    end

    it "should concat" do
      Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1
          roll in1
        end

      end

      expect(av_out_file.length).to be_approximately 12
    end

    it "should roll reels after specific time" do
      Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1
          roll in1, after: 3
        end

      end

      expect(av_out_file.length).to be_approximately 9

      Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1, after: 3
        end

      end

      expect(av_out_file.length).to be_approximately 9
    end


    [9, 18].each do |duration|
      it "should cut to precise duration (total 12 <=> cut after #{duration})" do
        Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

          in1 = input(file_input)
          output(file_output, resolution: Ffmprb::QVGA) do
            roll in1
            roll in1
            cut after: (duration - file_input.length)
          end
        end

        expect(av_out_file.length).to be_approximately duration
      end
    end

    it "should crop segments" do
      Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.crop(0.25)
          roll in1
        end

      end

      av_out_file.sample(at: 5, audio: true) do |snap, sound|
        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      av_out_file.sample(at: 7, audio: true) do |shot, sound|
        pixel = pixel_data(shot, 10, 10)
        expect(pixel.green + pixel.blue).to be < pixel.red/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
    end

    it "should cut and crop segments" do
      Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.cut(from: 0, to: 3).crop(0.25)
          roll in1
        end

      end

      av_out_file.sample(at: 2, audio: true) do |snap, sound|
        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      av_out_file.sample(at: 5, audio: true) do |shot, sound|
        pixel = pixel_data(shot, 10, 10)
        expect(pixel.green + pixel.blue).to be < pixel.red/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      expect(av_out_file.length).to be_approximately 9
    end

    it "should cut segments in any order" do
      Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.cut(from: 4, to: 6)
          roll in1.cut(from: 0, to: 2).crop(0.25)
        end

      end

      av_out_file.sample(at: 1, audio: true) do |shot, sound|
        pixel = pixel_data(shot, 10, 10)
        expect(pixel.green + pixel.blue).to be < pixel.red/2
        expect(wave_data(sound).frequency).to be_approximately 1000
      end
      av_out_file.sample(at: 3, audio: true) do |snap, sound|
        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      expect(av_out_file.length).to be_approximately 4
    end

    it "should detect silence and pass input to output" do
      silence = Ffmprb.find_silence(@av_file_wtb, av_out_file)
      expect(silence.length).to eq 2
      prev_silent_end_at = 0
      silence.each do |silent|
        av_out_file.sample at: silent.start_at + 1, audio: true do |image, sound|
          expect(wave_data(sound).volume).to eq nil
          pixel_data(image, 100, 100).tap do |pixel|
            expect(pixel.red + pixel.green + pixel.blue).to eq 0
          end
        end
        av_out_file.sample at: (prev_silent_end_at + silent.start_at)/2, audio: true do |image, sound|
          expect(wave_data(sound).volume).not_to eq nil
          pixel_data(image, 100, 100).tap do |pixel|
            expect(pixel.red + pixel.green + pixel.blue).to eq 3*0xFFFF
          end
        end
        prev_silent_end_at = silent.end_at
      end
    end

    context "media" do

      let(:m_input) {{video: @v_file, audio: @a_file}}
      let(:m_output_extname) {{video: '.y4m', audio: '.mp3'}}

      [:video, :audio].each do |medium|
        [
          lambda do |av_file_input, m_file_input, m_file_output|  ##1
            in1 = input(av_file_input)
            output(m_file_output, only: medium) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##2
            in1 = input(av_file_input)
            output(m_file_output) do
              roll in1.send(medium).cut(from: 3, to: 5)
              roll in1.send(medium).cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##3
            in1 = input(av_file_input, only: medium)
            output(m_file_output) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##4
            in1 = input(m_file_input)
            output(m_file_output, only: medium) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##5
            in1 = input(m_file_input)
            output(m_file_output) do
              roll in1.send(medium).cut(from: 3, to: 5)
              roll in1.send(medium).cut(from: 3, to: 5)
            end
          end,
          lambda do |av_file_input, m_file_input, m_file_output|  ##6
            in1 = input(m_file_input, only: medium)
            output(m_file_output) do
              roll in1.cut(from: 3, to: 5)
              roll in1.cut(from: 3, to: 5)
            end
          end
        ].each_with_index do |script, i|

          it "should work with video only and audio only, as input and as output (#{medium}##{i+1})" do

            Ffmprb::File.temp(m_output_extname[medium]) do |m_output|

              Ffmprb.process(@av_file_gor, m_input[medium], m_output, &script)

              m_output.sample(at: 2.5, medium => true, ([:video, :audio] - [medium])[0] => false) do |sample|
                case medium
                when :video
                  pixel = pixel_data(sample, 100, 100)
                  expect(pixel.red + pixel.blue).to be < pixel.green/2
                when :audio
                  expect(wave_data(sample).frequency).to be_within(10).of(
                    if i < 3
                      1000
                    else
                      666
                    end
                  )
                end
              end

              expect(m_output.length).to be_approximately 4


              expect{
                m_output.sample(at: 3, ([:video, :audio] - [medium])[0] => true, medium => false)
              }.to raise_error Ffmprb::Error

            end

          end

        end
      end
    end

    context "stitching" do

      let(:another_input_filename) {'spec/support/assets/rainbow-octave-14sec-60fps-320x240.mp4'}
      let(:another_input_path) {File.expand_path("../../#{another_input_filename}", __FILE__)}
      let(:another_file_input) {Ffmprb::File.open another_input_path}

      it "should transition between two reels" do
        Ffmprb.process(@av_file_gor, another_file_input, av_out_file) do |input1, input2, output1|

          in1, in2 = input(input1), input(input2)
          output(output1, resolution: Ffmprb::QVGA) do
            roll in1.crop(0.25), transition: {blend: 2}
            roll in2, after: 3, transition: {blend: 1.5}
          end

        end

        last_green = 0
        last_volume = 0
        times = [0, 1, 2]
        times.each do |at|
          av_out_file.sample(at: at, audio: true) do |snap, sound|
            pixel = pixel_data(snap, 10, 10)
            expect(pixel.red + pixel.blue).to be < pixel.green/2
            expect(pixel.green).to be > last_green  unless at == times.first
            last_green = pixel.green
            wave = wave_data(sound)
            expect(wave.frequency).to be_within(10).of 1000
            expect(wave.volume).to be > last_volume  unless at == times.first
            last_volume = wave.volume
          end
        end

        last_red = 0
        last_frequency = 0
        times = [3.5, 4, 4.5]
        times.each do |at|
          av_out_file.sample(at: at, audio: true) do |snap, sound|
            pixel = pixel_data(snap, 10, 10)
            expect(pixel.green + pixel.blue).to be < pixel.red/2  if at == times.last
            expect(pixel.red).to be > last_red  if at != times.first
            last_red = pixel.red
            wave = wave_data(sound)
            expect(wave.frequency).to be_between(1000 - 10, NOTES.C6 + 10)  unless at == times.last
            expect(wave.frequency).to be > last_frequency  unless at == times.first
            last_frequency = wave.frequency
          end
        end

        expect(av_out_file.length).to be_approximately 17
      end

      it "should montage a flick with transitions" do
        Ffmprb.process(another_file_input, av_out_file) do |input1, output1|

          in1 = input(input1)
          output(output1, resolution: Ffmprb::QVGA) do
            roll in1.cut(to: 3), transition: {blend: 1}
            roll in1.cut(from: 6, to: 9), after: 2, transition: {blend: 1}
            roll in1.cut(from: 10), after: 2, transition: {blend: 1}
            cut after: 2, transition: {blend: 1}
          end

        end

        reds = [0.25, 0.5, 1].map do |at|
          av_out_file.sample(at: at) do |snap|
            pixel_data(snap, 100, 100).red
          end
        end
        expect(reds).to eq reds.uniq
        expect(reds).to eq reds.sort

        greens = [2.25, 2.5, 3].map do |at|
          av_out_file.sample(at: at) do |snap|
            pixel_data(snap, 100, 100).green
          end
        end
        expect(greens).to eq greens.uniq
        # expect(greens).to eq greens.sort

        blues = [4.25, 4.5, 5].map do |at|
          av_out_file.sample(at: at) do |snap|
            pixel_data(snap, 100, 100).blue
          end
        end
        expect(blues).to eq blues.uniq
        # expect(blues).to eq blues.sort

        blues2 = [6, 6.25, 6.75].map do |at|
          av_out_file.sample(at: at) do |snap|
            pixel_data(snap, 100, 100).blue
          end
        end
        expect(blues2).to eq blues2.uniq
        # expect(blues2.reverse).to eq blues2.sort.reverse

        expect(av_out_file.length).to be_approximately 7
      end

      it "should run an external effect tool for a transition"

    end

    context :audio_overlay do

      around do |example|
        Timeout::timeout(4) do
          example.run
        end
      end

      it "should overlay sound with volume" do
        # NOTE non-streaming output file requires additional development see #181845
        Ffmprb.process(@av_file_wtb, @a_file, stream_av_out_file) do |input1, input2, output1|

          in1 = input(input1)
          in2 = input(input2, only: :audio)
          output(output1) do
            roll in1.volume(0.1), transition: {blend: 1}
            overlay in2.cut(from: 4).volume(2.0 => 0.1, 4.0 => 0.9)
          end

        end

        vols = []

        stream_av_out_file.sample(at: 2, audio: true) do |snap, sound|
          pixel = pixel_data(snap, 100, 100)
          expect(pixel.red + pixel.green + pixel.blue).to eq 3*0xFFFF
          wave = wave_data(sound)
          expect(wave.frequency).to be_between(666, 1000)
          vols << wave.volume
        end

        vols << wave_data(stream_av_out_file.sample(at: 3, video: false, audio: true)).volume

        stream_av_out_file.sample(at: 6, audio: true) do |snap, sound|
          pixel = pixel_data(snap, 100, 100)
          expect(pixel.red + pixel.green + pixel.blue).to eq 0
          wave = wave_data(sound)
          vols << wave.volume
        end

        prev_vol = -9999
        vols.each do |vol|
          expect(vol).to be > prev_vol
          prev_vol = vol
        end

      end

      it "should duck the overlay sound wrt the main sound" do
        Ffmprb::Util::IoBuffer.block_size.tap do |block_size|
          begin
            Ffmprb::Util::IoBuffer.block_size = 8*1024

            # NOTE non-streaming output file requires additional development see #181845
            Ffmprb.process(@av_file_wtb, @a_file, stream_av_out_file) do |input1, input2, output1|

              in1 = input(input1)
              in2 = input(input2, only: :audio)
              output(output1) do
                roll in1, transition: {blend: 1}
                overlay in2.cut(from: 4), duck: :audio
              end

            end

            stream_av_out_file.sample(at: 2, audio: true) do |snap, sound|
              pixel = pixel_data(snap, 100, 100)
              expect(wave_data(sound).frequency).to be_between(666, 880)
            end

            stream_av_out_file.sample(at: 6, audio: true) do |snap, sound|
              pixel = pixel_data(snap, 100, 100)
              expect(wave_data(sound).frequency).to be_within(10).of 666
            end
          ensure
            Ffmprb::Util::IoBuffer.block_size = block_size
          end
        end
      end

      it "should duck some overlay sound wrt some main sound" do
        Ffmprb::Util::IoBuffer.block_size.tap do |block_size|
          begin
            Ffmprb::Util::IoBuffer.block_size = 8*1024

            # NOTE non-streaming output file requires additional development see #181845
            Ffmprb.process(@a_file, a_out_file) do |input1, output1|

              in1 = input(input1, only: :audio)
              output(output1) do
                roll in1.cut(from: 4, to: 12), transition: {blend: 1}
                overlay in1, duck: :audio
              end

            end

            expect(a_out_file.length).to be_approximately(8)

            expect(wave_data(a_out_file.sample(at: 2, video: false, audio: true)).frequency).to be_within(10).of 666
            expect(wave_data(a_out_file.sample(at: 6, video: false, audio: true)).frequency).to be_within(10).of 666
          ensure
            Ffmprb::Util::IoBuffer.block_size = block_size
          end
        end
      end

    end

    context :samples do

      let(:output_extname) {'.jpg'}

      xit "should shoot snaps" do  # XXX not sure if this functionality is needed
        Ffmprb.process(@av_file_gor, av_out_file) do |file_input, file_output|

          in1 = input(file_input)
          video(resolution: Ffmprb::HD_1080p) do
            roll in1
            sample file_output, at: 3
          end

        end

        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
      end

    end

  end

  context :info do

    it "should return the length of a clip" do
      expect(@av_file_gor.length).to be_approximately 6
    end

  end

  def pixel_data(snap, x, y)
    Magick::Image.read(snap.path).first.pixel_color(x, y)
  end

  def wave_data(sound)
    sox_info = Ffmprb::Util.sh(Sox::SOX_COMMAND, sound.path, '-n', 'stat', output: :stderr)

    OpenStruct.new.tap do |data|
      data.frequency = $1.to_f  if sox_info =~ /Rough\W+frequency:\W*(\d+)/
      data.volume = -$1.to_f  if sox_info =~ /Volume\W+adjustment:\W*(\d+)/
    end
  end

end

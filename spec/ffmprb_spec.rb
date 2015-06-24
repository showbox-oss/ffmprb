require 'ostruct'

require 'rmagick'
require 'sox'

def be_approximately(sec)
  be_within(0.006 * sec).of sec
end

describe Ffmprb do

  it 'has a version number' do
    expect(Ffmprb::VERSION).not_to be nil
  end

  let(:input_filename) {'spec/support/assets/green-red_frame-20-sine-1000-6sec-60fps-320x240.mp4'}
  let(:input_path) {File.expand_path("../../#{input_filename}", __FILE__)}

  context :process do

    let(:output_extname) {'.mp4'}
    let(:file_input) {Ffmprb::File.open input_path}

    around do |example|
      Ffmprb::File.temp(output_extname) do |tf|
        @file_output = tf
        example.run
      end
    end

    let(:file_output) {@file_output}

    it "should transcode" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1
        end

      end

      expect(file_output.resolution).to eq Ffmprb::QVGA
      expect(file_output.length).to be_approximately 6
    end

    it "should concat" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1
          roll in1
        end

      end

      expect(file_output.length).to be_approximately 12
    end

    it "should roll reels after specific time" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1
          roll in1, after: 3
        end

      end

      expect(file_output.length).to be_approximately 9

      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1, after: 3
        end

      end

      expect(file_output.length).to be_approximately 9
    end


    [9, 18].each do |duration|
      it "should cut to precise duration (total 12 <=> cut after #{duration})" do
        Ffmprb.process(file_input, file_output) do |file_input, file_output|

          in1 = input(file_input)
          output(file_output, resolution: Ffmprb::QVGA) do
            roll in1
            roll in1
            cut after: (duration - file_input.length)
          end
        end

        expect(file_output.length).to be_approximately duration
      end
    end

    it "should crop segments" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.crop(0.25)
          roll in1
        end

      end

      file_output.snap_shot(at: 5, audio: true) do |snap, sound|
        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      file_output.snap_shot(at: 7, audio: true) do |shot, sound|
        pixel = pixel_data(shot, 10, 10)
        expect(pixel.green + pixel.blue).to be < pixel.red/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
    end

    it "should cut and crop segments" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.cut(from: 0, to: 3).crop(0.25)
          roll in1
        end

      end

      file_output.snap_shot(at: 2, audio: true) do |snap, sound|
        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      file_output.snap_shot(at: 5, audio: true) do |shot, sound|
        pixel = pixel_data(shot, 10, 10)
        expect(pixel.green + pixel.blue).to be < pixel.red/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      expect(file_output.length).to be_approximately 9
    end

    it "should cut segments in any order" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.cut(from: 4, to: 6)
          roll in1.cut(from: 0, to: 2).crop(0.25)
        end

      end

      file_output.snap_shot(at: 1, audio: true) do |shot, sound|
        pixel = pixel_data(shot, 10, 10)
        expect(pixel.green + pixel.blue).to be < pixel.red/2
        expect(wave_data(sound).frequency).to be_approximately 1000
      end
      file_output.snap_shot(at: 3, audio: true) do |snap, sound|
        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
        expect(wave_data(sound).frequency).to be_within(10).of 1000
      end
      expect(file_output.length).to be_approximately 4
    end

    context :snap_shots do

      let(:output_extname) {'.jpg'}

      xit "should shoot snaps" do  # XXX not sure if this functionality is needed
        Ffmprb.process(file_input, file_output) do |file_input, file_output|

          in1 = input(file_input)
          video(resolution: Ffmprb::HD_1080p) do
            roll in1
            snap_shot file_output, at: 3
          end

        end

        pixel = pixel_data(snap, 10, 10)
        expect(pixel.red + pixel.blue).to be < pixel.green/2
      end

    end

  end

  context :info do

    subject {Ffmprb::File.open input_path}

    it "should return the length of a clip" do
      expect(subject.length).to eq 6
    end

  end

  def pixel_data(snap, x, y)
    Magick::Image.read(snap.path).first.pixel_color(x, y)
  end

  def wave_data(sound)
    sox_info = Ffmprb::Util.sh("#{Sox::SOX_COMMAND} #{sound.path} -n stat", output: :stderr)

    OpenStruct.new.tap do |data|
      data.frequency = $1.to_f  if sox_info =~ /Rough\W+frequency:\W*(\d+)/
      data.volume = $1.to_f  if sox_info =~ /Volume\W+adjustment:\W*(\d+)/
    end
  end

end

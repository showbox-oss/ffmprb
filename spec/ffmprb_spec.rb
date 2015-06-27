require 'ostruct'

require 'rmagick'
require 'sox'

def be_approximately(sec)
  be_within(0.015 * sec).of sec
end

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


    context "stitching" do

      let(:another_input_filename) {'spec/support/assets/rainbow-octave-14sec-60fps-320x240.mp4'}
      let(:another_input_path) {File.expand_path("../../#{another_input_filename}", __FILE__)}
      let(:another_file_input) {Ffmprb::File.open another_input_path}

      it "should transition between two reels" do
        Ffmprb.process(file_input, another_file_input, file_output) do |input1, input2, output1|

          in1, in2 = input(input1), input(input2)
          output(output1, resolution: Ffmprb::QVGA) do
            roll in1.crop(0.25), transition: {blend: 2}
            roll in2, after: 3, transition: {blend: 2}
          end

        end

        last_green = 0
        last_volume = 0
        times = [0, 1, 2]
        times.each do |at|
          file_output.snap_shot(at: at, audio: true) do |snap, sound|
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
        times = [3, 4, 5]
        times.each do |at|
          file_output.snap_shot(at: at, audio: true) do |snap, sound|
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

        expect(file_output.length).to be_approximately 17
      end

      it "should montage a flick with transitions" do
        Ffmprb.process(another_file_input, file_output) do |input1, output1|

          in1 = input(input1)
          output(output1, resolution: Ffmprb::QVGA) do
            roll in1.cut(to: 3), transition: {blend: 1}
            roll in1.cut(from: 6, to: 9), after: 2, transition: {blend: 1}
            roll in1.cut(from: 10), after: 2, transition: {blend: 1}
            cut after: 2, transition: {blend: 1}
          end

        end

        reds = [0.25, 0.5, 1].map do |at|
          file_output.snap_shot(at: at) do |snap|
            pixel_data(snap, 100, 100).red
          end
        end
        expect(reds).to eq reds.uniq
        expect(reds).to eq reds.sort

        greens = [2.25, 2.5, 3].map do |at|
          file_output.snap_shot(at: at) do |snap|
            pixel_data(snap, 100, 100).green
          end
        end
        expect(greens).to eq greens.uniq
        # expect(greens).to eq greens.sort

        blues = [4.25, 4.5, 5].map do |at|
          file_output.snap_shot(at: at) do |snap|
            pixel_data(snap, 100, 100).blue
          end
        end
        expect(blues).to eq blues.uniq
        # expect(blues).to eq blues.sort

        blues2 = [6, 6.25, 6.75].map do |at|
          file_output.snap_shot(at: at) do |snap|
            pixel_data(snap, 100, 100).blue
          end
        end
        expect(blues2).to eq blues2.uniq
        # expect(blues2.reverse).to eq blues2.sort.reverse

        expect(file_output.length).to be_approximately 7
      end

      it "should run an external effect tool for a transition"

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
      data.volume = -$1.to_f  if sox_info =~ /Volume\W+adjustment:\W*(\d+)/
    end
  end

end

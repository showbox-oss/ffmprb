require 'rmagick'

describe Ffmprb do

  it 'has a version number' do
    expect(Ffmprb::VERSION).not_to be nil
  end

  let(:input_filename) {'spec/support/assets/green-red_frame-20-6sec-60fps-320x240.mp4'}
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
          roll in1, full_screen: true
        end

      end

      expect(file_output.resolution).to eq Ffmprb::QVGA
      expect(file_output.length).to be_within(0.1).of 6
    end

    it "should concat" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1, full_screen: true
          roll in1, full_screen: true
        end

      end

      expect(file_output.length).to be_within(0.1).of 12
    end

    it "should roll reels after specific time" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1, full_screen: true
          roll in1, after: 3, full_screen: true
        end

      end

      expect(file_output.length).to be_within(0.1).of 9

      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1, after: 3, full_screen: true
        end

      end

      expect(file_output.length).to be_within(0.1).of 9
    end


    [9, 18].each do |duration|
      it "should cut to precise duration (total 12 <=> cut after #{duration})" do
        Ffmprb.process(file_input, file_output) do |file_input, file_output|

          in1 = input(file_input)
          output(file_output, resolution: Ffmprb::QVGA) do
            roll in1, full_screen: true
            roll in1, full_screen: true
            cut after: (duration - file_input.length)
          end
        end

        expect(file_output.length).to be_within(0.1).of duration
      end
    end

    it "should crop segments" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.crop(0.25), full_screen: true
          roll in1, full_screen: true
        end

      end

      file_output.snap_shot(at: 5) do |snap|
        pixel_color(snap, 10, 10).tap do |pixel|
          expect(pixel.red + pixel.blue).to be < pixel.green/2
        end
      end
      file_output.snap_shot(at: 7) do |shot|
        pixel_color(shot, 10, 10).tap do |pixel|
          expect(pixel.green + pixel.blue).to be < pixel.red/2
        end
      end
    end

    it "should cut and crop segments" do
      Ffmprb.process(file_input, file_output) do |file_input, file_output|

        in1 = input(file_input)
        output(file_output, resolution: Ffmprb::QVGA) do
          roll in1.cut(from: 2, to: 4).crop(0.25), full_screen: true
          roll in1, full_screen: true
        end

      end

      file_output.snap_shot(at: 3) do |snap|
        pixel_color(snap, 10, 10).tap do |pixel|
          expect(pixel.red + pixel.blue).to be < pixel.green/2
        end
      end
      file_output.snap_shot(at: 5) do |shot|
        pixel_color(shot, 10, 10).tap do |pixel|
          expect(pixel.green + pixel.blue).to be < pixel.red/2
        end
      end
      expect(file_output.length).to be_within(0.1).of 10
    end

    context :snap_shots do

      let(:output_extname) {'.jpg'}

      xit "should shoot snaps" do  # XXX not sure if this functionality is needed
        Ffmprb.process(file_input, file_output) do |file_input, file_output|

          in1 = input(file_input)
          video(resolution: Ffmprb::HD_1080p) do
            roll in1, full_screen: true
            snap_shot file_output, at: 3
          end

        end

        pixel_color(snap, 10, 10).tap do |pixel|
          expect(pixel.red + pixel.blue).to be < pixel.green/2
        end
      end

    end

  end

  context :info do

    subject {Ffmprb::File.open input_path}

    it "should return the length of a clip" do
      expect(subject.length).to eq 6
    end

  end

  def pixel_color(snap, x, y)
    Magick::Image.read(snap.path).first.pixel_color(x, y)
  end

end

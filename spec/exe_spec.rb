describe Ffmprb::Execution do

  let(:ffmprb_src) { <<-FFMPRB
    |av_main_i, a_over_i, av_main_o|

    in1 = input(av_main_i)
    in2 = input(a_over_i)
    output(av_main_o) do
      roll in1
      overlay in2
    end

    FFMPRB
  }
  around do |example|
    Ffmprb::File.temp('.flv') do |tf|
      @av_file_o = tf
      Ffmprb::File.temp('.ffmprb') do |tf|
        tf.write ffmprb_src
        @ffmprb_file = tf
        example.run
      end
    end
  end

  it "should run the script" do
    cmd = "exe/ffmprb #{@av_file_c_gor_9.path} #{@a_file_g_16.path} #{@av_file_o.path} < #{@ffmprb_file.path}"

    expect(Ffmprb::Util.sh cmd).to match /WARN.+Output file exists/  # NOTE temp files are _created_ above
    expect(@av_file_o.length).to be_approximately @av_file_c_gor_9.length
  end

  it "should warn about the looping limitation" do

    [[270, :to], [120, :not_to]].each do |cut, to_not_to|
      outp_s = Ffmprb::Util.sh(
        "exe/ffmprb #{@av_file_c_gor_9.path} #{@av_file_o.path}", input: <<-FFMPRB
          |av_main_i, av_main_o|

          in1 = input(av_main_i)
          output(av_main_o) do
            roll in1.loop.cut(to: #{cut})
          end

        FFMPRB
      )
      expect(outp_s).send to_not_to, match(/WARN.+Looping.+finished before its consumer/)
      expect(@av_file_o.length true).to be_approximately cut
    end
  end

end

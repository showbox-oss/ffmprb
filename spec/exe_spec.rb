describe Ffmprb::Execution do

  around do |example|
    Ffmprb::File.temp('.flv') do |tf|
      @av_file_o = tf
      example.run
    end
  end

  it "should run the script (no params)" do
    Ffmprb::File.temp('.ffmprb') do |tf|
      tf.write <<-FFMPRB

        output('#{@av_file_o.path}') do
          roll input('#{@av_file_c_gor_9.path}')
          overlay input('#{@a_file_g_16.path}')
        end

        FFMPRB

      cmd = "exe/ffmprb < #{tf.path}"

      expect(Ffmprb::Util.sh cmd, output: :stderr).to match /WARN.+Output file exists/  # NOTE temp files are _created_ above
      expect(@av_file_o.length).to be_approximately @av_file_c_gor_9.length
    end
  end

  it "should run the script" do
    Ffmprb::File.temp('.ffmprb') do |tf|
      tf.write <<-FFMPRB
        |av_main_i, a_over_i, av_main_o|

        in1 = input(av_main_i)
        in2 = input(a_over_i)
        output(av_main_o) do
          roll in1
          overlay in2
        end

      FFMPRB

      cmd = "exe/ffmprb #{@av_file_c_gor_9.path} #{@a_file_g_16.path} #{@av_file_o.path} < #{tf.path}"

      expect(Ffmprb::Util.sh cmd, output: :stderr).to match /WARN.+Output file exists/  # NOTE temp files are _created_ above
      expect(@av_file_o.length).to be_approximately @av_file_c_gor_9.length
    end
  end

  [['', 300, :to], [' not', 90, :not_to]].each do |wat, cut, to_not_to|
    it "should#{wat} warn about the looping limitation" do

      inp_s = <<-FFMPRB

        in1 = input('#{@av_file_c_gor_9.path}')
        output('#{@av_file_o.path}') do
          roll in1.loop.cut(to: #{cut})
        end

      FFMPRB
      expect(Ffmprb::Util.sh 'exe/ffmprb', input: inp_s, output: :stderr).send to_not_to, match(/WARN.+Looping.+finished before its consumer/)
      expect(@av_file_o.length true).to be_approximately cut
    end
  end

end

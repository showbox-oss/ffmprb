# ffmprb
## your audio/video montage friend, based on [ffmpeg](https://ffmpeg.org)

A DSL (Damn-Simple Language) and a micro-engine for ffmpeg and ffriends.

Allows for code like
```ruby
av_raw = Ffmprb::File.open('flick.mp4')
a_track = Ffmprb::File.open('track.wav')
av_final = Ffmprb::File.create('cine.flv')
Ffmprb.process(av_raw, a_track, av_final) do |av_input1, a_input1, av_output1|

  in_main = input(av_input1)
  in_sound = input(a_input1, only: :audio)
  output(av_output1, resolution: Ffmprb::HD_720p) do
    roll in_main.cut(from: 2, to: 5).crop(0.25), transition: {blend: 1}
    roll in_main.cut(from: 6).volume(2), after: 2, transition: {blend: 1}
    cut after: 10, transition: {blend: 1}
    overlay in_sound.volume(0.8), duck: :audio
  end

end
```
and saves you from the horrors of (the native ffmpeg equivalent)
```
ffmpeg -y -i flick.mp4 -i track.wav -filter_complex "[0:v] copy [tmcpsp0:v]; [0:a] anull [tmcpsp0:a]; [tmcpsp0:v] trim=2:5, setpts=PTS-STARTPTS [cpsp0:v]; [tmcpsp0:a] atrim=2:5, asetpts=PTS-STARTPTS [cpsp0:a]; [cpsp0:v] crop=x=in_w*0.25:y=in_h*0.25:w=in_w*0.5:h=in_h*0.5 [sp0:v]; [cpsp0:a] anull [sp0:a]; [sp0:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, fps=fps=30 [rl0:v]; [sp0:a] anull [rl0:a]; color=black:d=1.0:s=1280x720:r=30 [bl0:v]; aevalsrc=0:d=1.0 [bl0:a]; [bl0:v] trim=0:1.0, setpts=PTS-STARTPTS [tm0b:v]; [bl0:a] atrim=0:1.0, asetpts=PTS-STARTPTS [tm0b:a]; color=white:d=1.0:s=1280x720:r=30 [rn70152323222540:v]; [tm0b:v] [rn70152323222540:v] alphamerge, fade=out:d=1.0:alpha=1 [xrn70152323222540:v]; [rl0:v] [xrn70152323222540:v] overlay=x=0:y=0:eof_action=pass [tn0:v]; [tm0b:a] afade=out:d=1.0 [rn70152323222540:a]; [rl0:a] afade=in:d=1.0 [xrn70152323222540:a]; [xrn70152323222540:a] [rn70152323222540:a] amix=2:duration=first [tn0:a]; [0:v] copy [tmldsp1:v]; [0:a] anull [tmldsp1:a]; [tmldsp1:v] trim=6, setpts=PTS-STARTPTS [ldsp1:v]; [tmldsp1:a] atrim=6, asetpts=PTS-STARTPTS [ldsp1:a]; [ldsp1:v] copy [sp1:v]; [ldsp1:a] volume='2':eval=frame [sp1:a]; [sp1:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, fps=fps=30 [rl1:v]; [sp1:a] anull [rl1:a]; color=black:d=3.0:s=1280x720:r=30 [bltn01:v]; aevalsrc=0:d=3.0 [bltn01:a]; [tn0:v] [bltn01:v] concat=2:v=1:a=0 [pdtn01:v]; [tn0:a] [bltn01:a] concat=2:v=0:a=1 [pdtn01:a]; [pdtn01:v] split [pdtn01a:v] [pdtn01b:v]; [pdtn01:a] asplit [pdtn01a:a] [pdtn01b:a]; [pdtn01a:v] trim=0:2, setpts=PTS-STARTPTS [tmtn01a:v]; [pdtn01a:a] atrim=0:2, asetpts=PTS-STARTPTS [tmtn01a:a]; [pdtn01b:v] trim=2:3.0, setpts=PTS-STARTPTS [tm1b:v]; [pdtn01b:a] atrim=2:3.0, asetpts=PTS-STARTPTS [tm1b:a]; color=white:d=1.0:s=1280x720:r=30 [rn70152323237760:v]; [tm1b:v] [rn70152323237760:v] alphamerge, fade=out:d=1.0:alpha=1 [xrn70152323237760:v]; [rl1:v] [xrn70152323237760:v] overlay=x=0:y=0:eof_action=pass [tn1:v]; [tm1b:a] afade=out:d=1.0 [rn70152323237760:a]; [rl1:a] afade=in:d=1.0 [xrn70152323237760:a]; [xrn70152323237760:a] [rn70152323237760:a] amix=2:duration=first [tn1:a]; color=black:d=11.0:s=1280x720:r=30 [bltn12:v]; aevalsrc=0:d=11.0 [bltn12:a]; [tn1:v] [bltn12:v] concat=2:v=1:a=0 [pdtn12:v]; [tn1:a] [bltn12:a] concat=2:v=0:a=1 [pdtn12:a]; [pdtn12:v] split [pdtn12a:v] [pdtn12b:v]; [pdtn12:a] asplit [pdtn12a:a] [pdtn12b:a]; [pdtn12a:v] trim=0:10, setpts=PTS-STARTPTS [tmtn12a:v]; [pdtn12a:a] atrim=0:10, asetpts=PTS-STARTPTS [tmtn12a:a]; color=black:d=1.0:s=1280x720:r=30 [bk2:v]; aevalsrc=0:d=1.0 [bk2:a]; [pdtn12b:v] trim=10:11.0, setpts=PTS-STARTPTS [tm2b:v]; [pdtn12b:a] atrim=10:11.0, asetpts=PTS-STARTPTS [tm2b:a]; color=white:d=1.0:s=1280x720:r=30 [rn70152323255640:v]; [tm2b:v] [rn70152323255640:v] alphamerge, fade=out:d=1.0:alpha=1 [xrn70152323255640:v]; [bk2:v] [xrn70152323255640:v] overlay=x=0:y=0:eof_action=pass [tn2:v]; [tm2b:a] afade=out:d=1.0 [rn70152323255640:a]; [bk2:a] afade=in:d=1.0 [xrn70152323255640:a]; [xrn70152323255640:a] [rn70152323255640:a] amix=2:duration=first [tn2:a]; [tmtn01a:v] [tmtn12a:v] [tn2:v] concat=3:v=1:a=0 [oo:v]; [tmtn01a:a] [tmtn12a:a] [tn2:a] concat=3:v=0:a=1 [oo:a]; [1:a] anull [ldol0:a]; [ldol0:a] volume='0.8':eval=frame [ol0:a]" -map "[oo:v]" -map "[oo:a]" /tmp/inter1a.flv -map "[ol0:a]" /tmp/inter1b.wav
```
then some scripting around
```
ffmpeg -y -i /tmp/inter1a.flv -filter_complex "silencedetect=d=2:n=-30dB" /tmp/inter2.flv
```
and finally
```
ffmpeg -y -i /tmp/inter2.flv -i /tmp/inter1b.wav -filter_complex "[0:v] copy [sp0:v]; [0:a] anull [sp0:a]; [sp0:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, fps=fps=30 [rl0:v]; [sp0:a] anull [rl0:a]; [rl0:v] concat=1:v=1:a=0 [oo:v]; [rl0:a] concat=1:v=0:a=1 [oo:a]; [1:a] anull [ldol0:a]; [ldol0:a] volume='if(between(t, 9.5, 10.5), (-0.8*t + 8.500000000000002)/1.0, if(between(t, 0.5, 9.5), 0.9, if(between(t, -0.5, 0.5), (0.8*t + 0.5)/1.0, if(between(t, 0.0, -0.5), 0.1, if(between(t, 0.0, 0.0), 0.1, 0.1)))))':eval=frame [ol0:a]; [oo:v] copy [oo0:v]; [oo:a] [ol0:a] amix=2:duration=first [oo0:a]" -map "[oo0:v]" -map "[oo0:a]" cine.flv
```
Umm... That's the idea.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ffmprb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ffmprb

## DSL & Usage

TODO: Write usage instructions here


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/showbox-oss/ffmprb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

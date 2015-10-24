# ffmprb
[![Gem Version](https://badge.fury.io/rb/ffmprb.svg)](http://badge.fury.io/rb/ffmprb)
[![Circle CI](https://circleci.com/gh/showbox-oss/ffmprb.svg?style=svg)](https://circleci.com/gh/showbox-oss/ffmprb)
## your audio/video montage pal, based on [ffmpeg](https://ffmpeg.org)

A DSL (Damn-Simple Language) and a micro-engine for ffmpeg and ffriends.

Allows for code like
```ruby
Ffmprb.process('flick.mp4', 'track.wav', 'cine.flv') do |av_input1, a_input1, av_output1|

  in_main = input(av_input1)
  in_sound = input(a_input1)
  output(av_output1, video: {resolution: Ffmprb::HD_720p}) do
    roll in_main.cut(from: 2, to: 5).crop(0.25), transition: {blend: 1}
    roll in_main.cut(from: 6, to: 16).volume(2), after: 2, transition: {blend: 1}
    overlay in_sound.volume(0.8), duck: :audio
  end

end
```
and saves you from the horrors of (the native ffmpeg equivalent)
```
ffmpeg -y -i flick.mp4 -i track.wav -filter_complex "[0:v] copy [tmcpsp0:v]; [0:a] anull [tmcpsp0:a]; [tmcpsp0:v] trim=2:5, setpts=PTS-STARTPTS [cpsp0:v]; [tmcpsp0:a] atrim=2:5, asetpts=PTS-STARTPTS [cpsp0:a]; [cpsp0:v] crop=x=in_w*0.25:y=in_h*0.25:w=in_w*0.5:h=in_h*0.5 [sp0:v]; [cpsp0:a] anull [sp0:a]; [sp0:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, fps=fps=30 [rl0:v]; [sp0:a] anull [rl0:a]; color=black:d=1.0:s=1280x720:r=30 [bl0:v]; aevalsrc=0:d=1.0 [bl0:a]; [bl0:v] trim=0:1.0, setpts=PTS-STARTPTS [tm0b:v]; [bl0:a] atrim=0:1.0, asetpts=PTS-STARTPTS [tm0b:a]; color=white:d=1.0:s=1280x720:r=30 [rn70152323222540:v]; [tm0b:v] [rn70152323222540:v] alphamerge, fade=out:d=1.0:alpha=1 [xrn70152323222540:v]; [rl0:v] [xrn70152323222540:v] overlay=x=0:y=0:eof_action=pass [tn0:v]; [tm0b:a] afade=out:d=1.0 [rn70152323222540:a]; [rl0:a] afade=in:d=1.0 [xrn70152323222540:a]; [xrn70152323222540:a] [rn70152323222540:a] amix=2:duration=first [tn0:a]; [0:v] copy [tmldsp1:v]; [0:a] anull [tmldsp1:a]; [tmldsp1:v] trim=6, setpts=PTS-STARTPTS [ldsp1:v]; [tmldsp1:a] atrim=6, asetpts=PTS-STARTPTS [ldsp1:a]; [ldsp1:v] copy [sp1:v]; [ldsp1:a] volume='2':eval=frame [sp1:a]; [sp1:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, fps=fps=30 [rl1:v]; [sp1:a] anull [rl1:a]; color=black:d=3.0:s=1280x720:r=30 [bltn01:v]; aevalsrc=0:d=3.0 [bltn01:a]; [tn0:v] [bltn01:v] concat=2:v=1:a=0 [pdtn01:v]; [tn0:a] [bltn01:a] concat=2:v=0:a=1 [pdtn01:a]; [pdtn01:v] split [pdtn01a:v] [pdtn01b:v]; [pdtn01:a] asplit [pdtn01a:a] [pdtn01b:a]; [pdtn01a:v] trim=0:2, setpts=PTS-STARTPTS [tmtn01a:v]; [pdtn01a:a] atrim=0:2, asetpts=PTS-STARTPTS [tmtn01a:a]; [pdtn01b:v] trim=2:3.0, setpts=PTS-STARTPTS [tm1b:v]; [pdtn01b:a] atrim=2:3.0, asetpts=PTS-STARTPTS [tm1b:a]; color=white:d=1.0:s=1280x720:r=30 [rn70152323237760:v]; [tm1b:v] [rn70152323237760:v] alphamerge, fade=out:d=1.0:alpha=1 [xrn70152323237760:v]; [rl1:v] [xrn70152323237760:v] overlay=x=0:y=0:eof_action=pass [tn1:v]; [tm1b:a] afade=out:d=1.0 [rn70152323237760:a]; [rl1:a] afade=in:d=1.0 [xrn70152323237760:a]; [xrn70152323237760:a] [rn70152323237760:a] amix=2:duration=first [tn1:a]; color=black:d=11.0:s=1280x720:r=30 [bltn12:v]; aevalsrc=0:d=11.0 [bltn12:a]; [tn1:v] [bltn12:v] concat=2:v=1:a=0 [pdtn12:v]; [tn1:a] [bltn12:a] concat=2:v=0:a=1 [pdtn12:a]; [pdtn12:v] split [pdtn12a:v] [pdtn12b:v]; [pdtn12:a] asplit [pdtn12a:a] [pdtn12b:a]; [pdtn12a:v] trim=0:10, setpts=PTS-STARTPTS [tmtn12a:v]; [pdtn12a:a] atrim=0:10, asetpts=PTS-STARTPTS [tmtn12a:a]; color=black:d=1.0:s=1280x720:r=30 [bk2:v]; aevalsrc=0:d=1.0 [bk2:a]; [pdtn12b:v] trim=10:11.0, setpts=PTS-STARTPTS [tm2b:v]; [pdtn12b:a] atrim=10:11.0, asetpts=PTS-STARTPTS [tm2b:a]; color=white:d=1.0:s=1280x720:r=30 [rn70152323255640:v]; [tm2b:v] [rn70152323255640:v] alphamerge, fade=out:d=1.0:alpha=1 [xrn70152323255640:v]; [bk2:v] [xrn70152323255640:v] overlay=x=0:y=0:eof_action=pass [tn2:v]; [tm2b:a] afade=out:d=1.0 [rn70152323255640:a]; [bk2:a] afade=in:d=1.0 [xrn70152323255640:a]; [xrn70152323255640:a] [rn70152323255640:a] amix=2:duration=first [tn2:a]; [tmtn01a:v] [tmtn12a:v] [tn2:v] concat=3:v=1:a=0 [oo:v]; [tmtn01a:a] [tmtn12a:a] [tn2:a] concat=3:v=0:a=1 [oo:a]; [1:a] anull [ldol0:a]; [ldol0:a] volume='0.8':eval=frame [ol0:a]" -map "[oo:v]" -map "[oo:a]" /tmp/inter1a.flv -map "[ol0:a]" /tmp/inter1b.wav
```
```
ffmpeg -y -i /tmp/inter1a.flv -filter_complex "silencedetect=d=2:n=-30dB" /tmp/inter2.flv
```
```
ffmpeg -y -i /tmp/inter2.flv -i /tmp/inter1b.wav -filter_complex "[0:v] copy [sp0:v]; [0:a] anull [sp0:a]; [sp0:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, fps=fps=30 [rl0:v]; [sp0:a] anull [rl0:a]; [rl0:v] concat=1:v=1:a=0 [oo:v]; [rl0:a] concat=1:v=0:a=1 [oo:a]; [1:a] anull [ldol0:a]; [ldol0:a] volume='if(between(t, 9.5, 10.5), (-0.8*t + 8.500000000000002)/1.0, if(between(t, 0.5, 9.5), 0.9, if(between(t, -0.5, 0.5), (0.8*t + 0.5)/1.0, if(between(t, 0.0, -0.5), 0.1, if(between(t, 0.0, 0.0), 0.1, 0.1)))))':eval=frame [ol0:a]; [oo:v] copy [oo0:v]; [oo:a] [ol0:a] amix=2:duration=first [oo0:a]" -map "[oo0:v]" -map "[oo0:a]" cine.flv
```
Umm... That's the idea.
The docs, as well as any other part of this gem, are a work in progress.
So you're very welcome to look around the [specs](https://github.com/showbox-oss/ffmprb/tree/master/spec) for the current functionality coverage.

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

The DSL strives to provide for the most common script cases in the most natural way:
you just describe what should be shown -- in an action sequence, like the following.

Play your _episode_ teaser snippet:
```ruby
lay episode.cut(to: 60), transition: {blend: 3}
```
Overlay anything after that with your channel _logo_:
```ruby
overlay logo.loop.cut(to: 33), after: 3, transition: {blend: 1}  # both ways
```
Start with rolling some _intro_ flick:
```ruby
lay intro, transition: {blend: 1}
```
Overlay it with some special _badge_ sprite:
```ruby
overlay badge.loop, at: 1, transition: {burn: 1}
```
Show _title_:
```ruby
lay title, transition: {blend: 2}
```
Play some of your _episode_:
```ruby
lay episode.cut(from: 60, to: 540)
```
Oh well, roll some _promo_ material:
```ruby
lay promo, transition: {pixel: 2}
```
Play most of your _episode_:
```ruby
lay episode.cut(from: 540, to: 1080)
```
Roll the _credits_:
```ruby
overlay credits, at: 1075
```
Finish by playing your special _outro_:
```ruby
lay outro, transition: {blend: 1}
```

Anything that follows this order will work -- the script may be generated on the fly:
```ruby
transitions = [:blend, :burn, :zoom]
photos.shuffle.each do |photo|
  lay photo.loop.cut(to: rand * 3), transition: {transitions.shuffle.first => 1}
end
```
All _inputs_ mentioned above must be supplied to `Ffmprb::process` as following
(the complete script as can be run with `ffmprb` CLI, see below):
```ruby
# script.ffmprb
|episode, logo, intro, badge, title, promo, credits, outro|

lay episode.cut(to: 60), transition: {blend: 3}
overlay logo.loop.cut(to: 33), after: 3, transition: {blend: 1}
lay intro, transition: {blend: 1}
overlay badge.loop, at: 1, transition: {burn: 1}
lay title, transition: {blend: 2}
lay episode.cut(from: 60, to: 540)
lay promo, transition: {pixel: 2}
lay episode.cut(from: 540, to: 1080)
overlay credits, at: 535
lay outro, transition: {blend: 1}
```

### Attention

- Ffmprb is a work in progress, and even more so than Ffmpeg itself;
use at your own risk and check thoroughly for production fitness in your project.
- Ffmprb uses threads internally, however, it is not thread-safe interface-wise:
you must not share its objects between different threads.



### General structure

Inside a `process` block, there are input definitions and output definitions;
naturally, the latter use the former:
```ruby
Ffmprb.process('flick.mp4', 'film.flv') do |av_input1, av_output1|

  in_main = input(av_input1)
  output(av_output1, video: {resolution: Ffmprb::HD_720p, fps: 25}) do
    roll in_main.crop(0.05), transition: {blend: 1}
  end

end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release` to create a git tag for the version, push git commits
and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Threading policy

Generally, avoid using threads, but not at any cost.
If you have to use threads -- like they're already in use in the code -- please
follow these simple principles:

- A parent thread, when in normal operation, will join _all_ its child threads --
  either via `#join` or `#value`.
- A child thread, when in normal _long-running_ operation, will check on its parent
  thread periodically -- probably together with logging/quitting operation itself on timeouts
  (either with a use of `Timeout.timeout` or otherwise):
  if it's dead with exception (status=nil), the child should die with exception as well.
- To avoid confusion, do not allow Timeout exception (or other thread-management-related
  errors) to escape threads (otherwise the joining parent must distinguish between
  its own timout and that of a joined thread)


## Contributing

1. Fork it ( https://github.com/showbox-oss/ffmprb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

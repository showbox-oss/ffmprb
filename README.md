# ffmprb
[![Gem Version](https://badge.fury.io/rb/ffmprb.svg)](http://badge.fury.io/rb/ffmprb)
[![Circle CI](https://circleci.com/gh/showbox-oss/ffmprb.svg?style=svg)](https://circleci.com/gh/showbox-oss/ffmprb)
## your audio/video montage pal, based on [ffmpeg](https://ffmpeg.org)

A DSL (Damn-Simple Language) and a micro-engine for ffmpeg and ffriends.

Allows for scripts like
```ruby
Ffmprb.process do

  in_main = input('flick.mp4')
  in_sound = input('track.mp3')
  output 'cine.flv', video: {resolution: '1280x720'} do
    roll in_main.crop(0.25).cut(from: 2, to: 5), transition: {blend: 1}
    roll in_main.volume(2).cut(from: 6, to: 16), after: 2, transition: {blend: 1}
    overlay in_sound.volume(0.8)
  end

end
```
and saves you from the horror of...
```
ffmpeg -y -noautorotate -i flick.mp4 -noautorotate -i track.wav -filter_complex "[0:v] fps=fps=16 [cptmo0rl0:v]; [0:a] anull [cptmo0rl0:a]; [cptmo0rl0:v] crop=x=in_w*0.25:y=in_h*0.25:w=in_w*0.5:h=in_h*0.5 [tmptmo0rl0:v]; [tmptmo0rl0:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), setsar=1, pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, setsar=1 [tmo0rl0:v]; [cptmo0rl0:a] anull [tmo0rl0:a]; color=0x000000@0:d=3:s=1280x720:r=16 [blo0rl0:v]; [tmo0rl0:v] [blo0rl0:v] concat=2:v=1:a=0 [pdo0rl0:v]; [pdo0rl0:v] trim=2:5, setpts=PTS-STARTPTS [o0rl0:v]; aevalsrc=0:d=3 [blo0rl0:a]; [tmo0rl0:a] [blo0rl0:a] concat=2:v=0:a=1 [pdo0rl0:a]; [pdo0rl0:a] atrim=2:5, asetpts=PTS-STARTPTS [o0rl0:a]; color=0x000000@0:d=1.0:s=1280x720:r=16 [bl0:v]; aevalsrc=0:d=1.0 [bl0:a]; [bl0:v] trim=0:1.0, setpts=PTS-STARTPTS [o0tm0b:v]; [bl0:a] atrim=0:1.0, asetpts=PTS-STARTPTS [o0tm0b:a]; color=0xFFFFFF@1:d=1.0:s=1280x720:r=16 [blndo0tm0b:v]; [o0tm0b:v] [blndo0tm0b:v] alphamerge, fade=out:d=1.0:alpha=1 [xblndo0tm0b:v]; [o0rl0:v] [xblndo0tm0b:v] overlay=x=0:y=0:eof_action=pass [o0tn0:v]; [o0tm0b:a] afade=out:d=1.0:curve=hsin [blndo0tm0b:a]; [o0rl0:a] afade=in:d=1.0:curve=hsin [xblndo0tm0b:a]; [blndo0tm0b:a] apad [apdblndo0tm0b:a]; [xblndo0tm0b:a] [apdblndo0tm0b:a] amix=2:duration=shortest:dropout_transition=0, volume=2 [o0tn0:a]; [0:v] scale=iw*min(1280/iw\,720/ih):ih*min(1280/iw\,720/ih), setsar=1, pad=1280:720:(1280-iw*min(1280/iw\,720/ih))/2:(720-ih*min(1280/iw\,720/ih))/2, setsar=1, fps=fps=16 [ldtmo0rl1:v]; [0:a] anull [ldtmo0rl1:a]; [ldtmo0rl1:v] copy [tmo0rl1:v]; [ldtmo0rl1:a] volume='2':eval=frame [tmo0rl1:a]; color=0x000000@0:d=10:s=1280x720:r=16 [blo0rl1:v]; [tmo0rl1:v] [blo0rl1:v] concat=2:v=1:a=0 [pdo0rl1:v]; [pdo0rl1:v] trim=6:16, setpts=PTS-STARTPTS [o0rl1:v]; aevalsrc=0:d=10 [blo0rl1:a]; [tmo0rl1:a] [blo0rl1:a] concat=2:v=0:a=1 [pdo0rl1:a]; [pdo0rl1:a] atrim=6:16, asetpts=PTS-STARTPTS [o0rl1:a]; color=0x000000@0:d=3.0:s=1280x720:r=16 [blo0tn01:v]; aevalsrc=0:d=3.0 [blo0tn01:a]; [o0tn0:v] [blo0tn01:v] concat=2:v=1:a=0 [pdo0tn01:v]; [o0tn0:a] [blo0tn01:a] concat=2:v=0:a=1 [pdo0tn01:a]; [pdo0tn01:v] split [pdo0tn01a:v] [pdo0tn01b:v]; [pdo0tn01:a] asplit [pdo0tn01a:a] [pdo0tn01b:a]; [pdo0tn01a:v] trim=0:2, setpts=PTS-STARTPTS [tmo0tn01a:v]; [pdo0tn01a:a] atrim=0:2, asetpts=PTS-STARTPTS [tmo0tn01a:a]; [pdo0tn01b:v] trim=2:3.0, setpts=PTS-STARTPTS [o0tm1b:v]; [pdo0tn01b:a] atrim=2:3.0, asetpts=PTS-STARTPTS [o0tm1b:a]; color=0xFFFFFF@1:d=1.0:s=1280x720:r=16 [blndo0tm1b:v]; [o0tm1b:v] [blndo0tm1b:v] alphamerge, fade=out:d=1.0:alpha=1 [xblndo0tm1b:v]; [o0rl1:v] [xblndo0tm1b:v] overlay=x=0:y=0:eof_action=pass [o0tn1:v]; [o0tm1b:a] afade=out:d=1.0:curve=hsin [blndo0tm1b:a]; [o0rl1:a] afade=in:d=1.0:curve=hsin [xblndo0tm1b:a]; [blndo0tm1b:a] apad [apdblndo0tm1b:a]; [xblndo0tm1b:a] [apdblndo0tm1b:a] amix=2:duration=shortest:dropout_transition=0, volume=2 [o0tn1:a]; [tmo0tn01a:v] [o0tn1:v] concat=2:v=1:a=0 [o0o:v]; [tmo0tn01a:a] [o0tn1:a] concat=2:v=0:a=1 [o0o:a]; [1:a] anull [ldo0l0:a]; [ldo0l0:a] volume='0.8':eval=frame [o0l0:a]; [o0o:v] copy [o0o0:v]; [o0l0:a] apad [apdo0l0:a]; [o0o:a] [apdo0l0:a] amix=2:duration=shortest:dropout_transition=0, volume=2 [o0o0:a]" -map [o0o0:v] -map [o0o0:a] -c:a libmp3lame cine.flv
```
...that's the idea, but there's much more to it.
The docs, as well as any other part of this gem, are a work in progress.
So you're very welcome to look around the [specs](https://github.com/showbox-oss/ffmprb/tree/master/spec) for the actual functionality coverage.

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
Ffmprb.process do |av_input1, av_output1|

  in_main = input('flick.mp4')
  output('film.flv', video: {resolution: Ffmprb::HD_720p, fps: 25}) do
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

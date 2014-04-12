# Jekyll Gallery Generator

A Jekyll Plugin for nice responsive galleries. Best used with [gallery.js](https://github.com/snrbrnjna/galleryjs).

## Install

Install via [bundler](http://bundler.io/) - put the following line in your Gemfile:

``` ruby 
gem jekyll_gallery_generator :git => https://github.com/snrbrnjna/jekyll_gallery_generator.git :tag => <semver>
```

### Development

``` bash
$ git clone https://github.com/snrbrnjna/jekyll_gallery_generator.git
$ cd jekyll_gallery_generator
$ npm install
$ bower install
$ bundle install
$ grunt serve
```

## Usage

### Jekyll

You need a gallery.html Layout File. 

You need a [frontend](https://github.com/snrbrnjna/galleryjs) for the gallery to work... Good, that it works via bower.

You need a [Configuration](/_config.yml): the params ``gems`` and ``gallery`` are the important ones.

## License

[modified MIT](/license.md)

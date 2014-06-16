---
layout: default
---

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

You need a [gallery.html](/_layouts/gallery.html) Layout File. 

You need a [frontend](https://github.com/snrbrnjna/galleryjs) for the gallery to work... Good, that it works via bower.

You need a [Configuration](/_config.yml): the params ``gems`` and ``gallery`` are the important ones.

Optionally, you need a [gallery_image.html](/_layouts/gallery_image.html) Layout File.  
When present and when the feature is switched on in the [config](/lib/jekyll_gallery_generator/generator.rb#L38) or in the [YAML Front Matter](/_posts/2014-04-09-small-test-gallery.md#L17) of your gallery posts, it serves as a layout for rendering every gallery image into its own page. The [gallery_image page](/_layouts/gallery_image.html) can be used for making every image shareable via twitter, facebook, etc.

## License

[modified MIT](/license.md)

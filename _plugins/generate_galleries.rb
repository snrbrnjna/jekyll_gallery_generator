# # Gallery Generator Plugin
#
# For the Gallery Plugin to work, you have to set some params in the _config.yml:
#
# src:
#   basepath: assets/img/_fullsize      # basedir where all the fullsize images are (in 'project'-subdirs, e.g. ./tessin-2012)
# dst:
#   basepath: assets/img/_galleries     # basedir where all the generated preset images are placed for copying it later to the site (in 'project'-subdirs, e.g. ./tessin-2012)
#   baseurl: /assets/img/galleries      # baseurl where all the generated preset images are accessible on the generated site (in 'project'-subdirs and 'preset'-subdirs)
# quality: 90                           # quality setting for generated JPGs
# presets                               # every images get created for all these presets 
#   thumb:
#      width: 400
#   large_phones:
#     width: 650
#   large_pads:
#     width: 1024
#   large:
#     width: 1400
# opts: <see YAML Front Matter gallery key>   # default values => see Gallery constructor
# 
# Notes on these params:
# - baseurl: can also specify an complete url with protocol and host if the files 
#            are uploaded to a external cdn.
# - presets: every preset can have a width or/and height attribute; this setting 
#            can be overriden in gallery posts YAML.
#
# Posts with gallery layout can have the following Params in their YAML Front 
# Matter:
#
# project: <project-name>         # e.g. tessin-2012
# presets:
#   thumb:
#     width: 300                  # default: 300
#   large:
#     width: 1400                 # default: 800
# regenerate_images: false        # default: false
# generate_gallery: false         # default: false
# dynamic_fill: false             # default: true
# pretty_json: true               # default: false
# quality: 90                     # default: value from config.yml
# gallery:                        # default: values from config.yml
#   minColWidth: <int> | <hash>   # min. width of masonry thumbs in gallery container
#   gutterWidth: <int>            # pixels between masonry cells
#   chunkSize: <int>              # number of thumbs to fetch via inview (default 8)
#   firstChunk: <int>             # number of thumbs fetched initially (default 15)
#
# Notes to these Params:
# - regenerate_images: generates all presets even if they are generated already
# - generate: generate the json (Read in every Image) even if the number of 
#             Images didn't change
# - dynamic_fill: when set to false all thumbs get rendered into the generated 
#                 gallery page => no responsive thumbs (all devices get the same
#                 thumbs)
# - pretty_json: make the generated gallery json pretty
# - gallery[:minColWidth]: 
#   - int: pixels
#   - hash: keys => mediaType as described in responsive.adapter.js; values: pixels



require './_plugins/generate_galleries/lib'


---
layout: default
title: Notes
---

## mache!
- [ ] FEAT: "Permalinks" für Sharing
  + [ ] Blank Page mit Bild und Metadata für Twitter
  + [ ] Metadata and Image for Gallery-Posts: erstes Bild, oder id eines Bildes 
        für FB/Twitter meta
- [ ] FEAT(jekyll): update to jekyll 2
- [ ] CHECK: klappt image_pages feature mit sets aus g.brnjna.net?
  + evtl Plan aushecken, wie Set plugin in dieses Projekt mit integriert oder 
    gekoppelt werden kann!
- [ ] FEAT: exif data in yaml abklemmen (default: kein exif ins json).

## merke!
- grunt tasks:
    + __serve__
      build dev version (jekyll & copy src) and serve with livereload on any change
    + __serve:dist__
      build dist version and serve it without livereload
    + __build__
      build dist version (jekyll & usemin)
    + __deploy__
      build und rsync zu in ``_config.deploy.yml`` konfiguriertem Ziel
    + __deploy:tunneled__
      build und rsync via tunnel.
- modernizer kommt nicht von bower_components, ist direkt von h5bp entliehen

## doku

### FEAT: Image Pages
- add url data to Gallery class (config: url, gallery#post_[base]path)
- render image pages (config: image_pages, gallery#image_pages)
- layout file for image_pages (till now only facebook)
gallery-config: image_pages: boolean

config-param: url

filter module

gallery#post_path, 
gallery#post_basepath,
gallery#image_pages

## changelog
### Aug 8, 2014
- [X] BUG: Generator: Imagesizes falsch in Report: der rechnet den durchschnitt aller Bilder, nicht der im JSON verwendeten...

### Aug 7, 2014
- [X] Chore: Gemfile/gemspec dings:
  - http://yehudakatz.com/2010/12/16/clarifying-the-roles-of-the-gemspec-and-gemfile/ 
  - http://bundler.io/rubygems.html

### Aug 6, 2014
- [X] FIX(minimagick): use symbols to access image props width and height

### Jun 18, 2014
- [X] FIX(image_pages): Title in page: '-' wenn kein meta title
- [X] REFACTOR(json): title meta datum was redundant in image json
- [X] FEAT(metadata) metadata für Gallery wie für Images (see layout gallery_image.html)

### Jun 17, 2014
- [X] FEAT(image_pages): gallery.js mit image_pages Feature verknüpfen

### Jun 16, 2014
- [X] FEAT(image_pages): "Permalinks" für Sharing
    + [X] Blank Page mit Bild und Metadata für 
        - [X] Facebook
    + [X] JS Redirect zu Galerie mit Slider offen.
  API-BREAKING you have to change your config (posts or site-wide) to use that feature (``image_pages: true``). Then you have to create a ``gallery_image.html`` layout file.

# Jun, 14
- [X] BUG: json file url klappt nur, wenn jekyll permalinks config is set to ``permalinks: none``
- [X] BUG: Wenn keine opts im YFM angegeben: leere opts im json
- [X] BUG: min_col_width als integer für alle devices klappt nicht.

### Jun 11, 14:
- [X] FEAT(galleryjs): update to v0.6.0.
  API-BREAKING you have to upgrade to ~0.6 in your bower.json and regenerate old galler posts, if you want to use the new galleryjs.

### Apr 24, 14: v0.4.0  
- [X] FIX: some stuff
- [X] FIX(eigentlich ein FEAZ): update auf galleryjs v0.5

### Apr 14, 14: v0.3.0  
- [X] FEAT: title, oder allgemeiner meta data zu den bildern ablegen in extra json, oder wie pack ich die bild-titel zu den bildern, sodass sie nicht gelöscht werden?

### Apr 12, 14: v0.2.0  
- [X] FEAT: made plugin a rubygem

### Apr 11, 14:  
- [X] REFACTOR: generator strategies for different tasks (config: do)

### Apr 02, 14: 
- [X] Refactoring: API-BREAKING lib-change
    - ``minColWidth`` wurde zu ``min_col_width``
    - ``chunkSize`` wurde zu ``chunk_size``
    - ``firstChunk`` wurde zu ``first_chunk``
    - YAML Front-Matter Change:
      + gallery stuff comes in extra Hash ``gallery_config``, which has same attribs than the site.config, plus some other gallery/instance-specific attributes
      + ``gallery`` attribute now is ``gallery_config['opts']``
      + ``generate_gallery`` und ``regenerate_images`` parameter are obsolete, use new commando interface instead:
        + ``do`` with one out of ``check_images|generate_data|generate_images|nothing``.
        + ``check_images`` is the default. 

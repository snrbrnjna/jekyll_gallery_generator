---
layout: page
title: Notes
---

## mache!
- [ ] FEAT: "Permalinks" für Sharing
  + [ ] Blank Page mit Bild und Metadata für 
    - [ ] Twitter
  + [ ] gallery.js mit image_pages Feature verknüpfen
- [ ] FEAT: metadata für Galery wie für Images
- [ ] REFACTOR: title in image json doppelt, filter json for redundant info => lightweight JSON
- [ ] CHECK: klappt image_pages feature mit sets aus g.brnjna.net?
  + evtl Plan aushecken, wie Set plugin in dieses Projekt mit integriert oder gekoppelt werden kann!
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

### Jun, 14:
- [X] FEAT(image_pages): "Permalinks" für Sharing
    + [X] Blank Page mit Bild und Metadata für 
        - [X] Facebook
    + [X] JS Redirect zu Galerie mit Slider offen.
- [X] BUG: json file url klappt nur, wenn jekyll permalinks config is set to ``permalinks: none``
- [X] BUG: Wenn keine opts im YFM angegeben: leere opts im json
- [X] BUG: min_col_width als integer für alle devices klappt nicht.


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
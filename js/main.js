$(function() {
  var galleryEl = $('.gallery-app');
  if (galleryEl.length) {
    new GalleryApp({el: galleryEl});
  }
});

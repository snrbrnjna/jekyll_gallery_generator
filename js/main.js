$(function() {
  var galleryEl = $('.gallery-app');
  if (galleryEl.length) {
    galleryEl.data('gallery', new GalleryApp({el: galleryEl}));
  }
});

require 'pathname'

module Jekyll
  module GalleryGenerator
    module Filter

      # Calculate the Image URL out of the json/liquid metadata
      def image_url_large gallery, image
        # normalize image url
        # if (!baseUrl.match(/http:\/\/|https:\/\//)) {
        #   var uri = parseUri(window.location.href);
        #   var root = uri.protocol+ '://' + uri.host + (uri.port ? ':' + uri.port : '');
        #   if (baseUrl.indexOf('/') === 0) { // absolute path
        #     preset['baseurl'] = root + baseUrl;
        #   } else { // relative path
        #     preset['baseurl'] = root + uri.directory + baseUrl;
        #   }
        # }
        image_baseurl = gallery['presets']['large']['baseurl']
        if (!image_baseurl.match(/http:\/\/|https:\/\/|^\//)) # relative path
          image_baseurl = (
            Pathname.new(gallery['post_basepath']) + image_baseurl
          ).cleanpath.to_s
        end
        image_baseurl = qualified_url(image_baseurl)
        File.join(image_baseurl, image['filename'])
      end

      # Get the calculated Image title
      def image_title gallery, image
        "#{gallery['title']} - #{image['meta']['title']}"
      end

      # Get the url of the Gallery Image to redirect to
      def image_redirect_url gallery, image
        "#{qualified_url(gallery['post_path'])}#!#{image['digest']}"
      end

      def qualified_url baseurl
        if (!baseurl.match(/http:\/\/|https:\/\//))
          site_baseurl = @context.registers[:site].config['url']
          unless site_baseurl
            raise "Error while generating an image url. You have to define a url " +
              "config var in your _config.yml!"
          end

          return File.join(site_baseurl, baseurl)
        end
        return baseurl
      end

    end
  end
end

module Jekyll
  module GalleryGenerator
    class GalleryGenerator < Generator
        
      priority :normal
      
      DEFAULTS = {
        'src' => {
          'basepath' => '_galleries/_fullsizes'
        }, 
        'dst' => {
          'basepath' => '_galleries/_generated',
          'baseurl' =>  '/img/galleries'
        }, 
        'presets' => {
          'thumb' =>        { 'width' =>  450 },
          'large_phones' => { 'width' =>  650 },
          'large_pads' =>   { 'width' => 1024 }, 
          'large' =>        { 'width' => 1400 } 
        },
        'quality' => 100,
        'opts' => {     # opts for gallery frontend
          'min_col_width' => {
            'desktop' =>  320,
            'pad' =>      320,
            'phone' =>    300
          },
          'gutterWidth' =>   3,
          'chunkSize' =>     8,
          'firstChunk' =>   15
        },
        'pretty_json' => false,
        'dynamic_fill' => true 
      }

      def generate site
        # set site wide gallery defaults
        @defaults = merge_defaults DEFAULTS, site.config['gallery']

        # Hash of all processed Gallery objects
        @galleries = {}; 

        # Save some stats for User Feedback
        @gallery_stats = []; @galleries_size = 0

        # filter gallery posts
        payload = site.site_payload
        gallery_posts = payload['site']['posts'].select do |post| 
          post.data['layout'] == 'gallery'
        end

        if gallery_posts.any?
          unless site.config['gallery']
            puts "There are Gallery-Posts, but no Gallery configuration, hence the galleries are not processed".red
          else
            # werden die generierten images auf dem selben Host abgelegt, auf dem 
            # auch die posts landen?
            images_remote = site.config['gallery']['dst']['baseurl'].start_with?('http://', 'https://')
      
            # Workaround.... for issue: https://github.com/mojombo/jekyll/issues/1297
            # Have to create a virtual static file in every subdirectory of 
            # gallery dst baseurl, else these directories are washed away by
            # Jekylls cleanup method...
            unless images_remote
              path_comps = site.config['gallery']['dst']['baseurl'].split(File::SEPARATOR)
              path_comps.each_with_index do |path_comp, idx|
                site.static_files << StaticGalleryFile.new(
                  site, '', File.join(path_comps[0, idx+1]), 'keepme'
                )
              end
            end
      
            # logging
            puts; puts "#### #{gallery_posts.size} Gallery-Posts"
                  
            gallery_posts.each do |gp|
                              
              # Front Matter YAML Data
              data = gp.data
          
              # Create Gallery instance
              begin
                # Build Options for Gallery constructor
                opts = merge_defaults @defaults, data['gallery_config']

                # TODO auch in Defaults mit aufnehmen
                opts['project'] = data['gallery_config']['project'] || gp.slug
                opts['regenerate_images'] = data['gallery_config']['regenerate_images'] if data['gallery_config'].has_key?('regenerate_images')
                opts['generate_gallery'] = data['gallery_config']['generate_gallery'] if data['gallery_config'].has_key?('generate_gallery')

                gallery = Jekyll::GalleryGenerator::Gallery.new(
                  site, data['title'], opts
                )
              rescue ArgumentError => error
                warn 'ERROR: '.red + error.message
                next
              end
          
              if (gp.published?)    
                # Add Gallery to post data (all Gallery#to_liquid data)
                gp.data['gallery'] = gallery                    
                
                # Create Image objects
                gallery.read_images
            
                # Check if gallery was proecessed yet (Set plugin)
                gallery_processed_yet = @galleries.keys.include?(gallery.project)
# TODO: hier bin ich im Ablauf-Diagramm            
                # Try to read in JSON if Gallery was processed in this generation yet or
                # because of the option to not generate it.
                status = nil
                if (gallery_processed_yet || 
                  (!gallery.generate? && File.exists?(json_path(site, gp, gallery))))
                  LOG.info "nothing to do, only read in the Gallery JSON " +
                    "for generating the gallery post"
                  
                  # Read in Gallery from json, so that gallery_post can get
                  # created by Mr. Jekyll
                  begin
                    gallery.read_json!(json_path(site, gp, gallery))
                    copy_json(site, gp, gallery)
                    status = :nothing
                  rescue Exception => e
                    LOG.info "JSON was corrupt, have to generate it again"
                  end
                end

                # Gallery has to be created because previous block didn't work out
                unless status == :nothing
                  # Generate resized images
                  gallery.generate_presets
                  # Write json
                  generate_json(site, gp, gallery)
                  copy_json(site, gp, gallery)
                  # Stats
                  status = :generate_presets
                end
                # end gallery generate
            
                # Copy generated images
                unless images_remote || gallery_processed_yet
                  copy_images(site, gallery)
                end # end copy images

                # Save log output for current gallery
                log_gallery(gallery, gallery_processed_yet, status)
            
                # Save gallery id for not generating a gallery twice
                @galleries[gallery.project] = gallery
             
              end # end published
          
            end # end gallery_posts
                
            # logging
            puts; puts @gallery_stats
            if @galleries_size < 7516192768
              puts "Total of #{@galleries_size.to_human}".green
            else 
              puts "Total of #{@galleries_size.to_human} CAUTION: your quota is going to be exhausted soon!".red
            end
          end # end site.config
        end # end gallery_posts.any?
      end # end generate



      # sets site wide gallery defaults
      def merge_defaults defaults, gallery_opts
        # Build Options for Gallery constructor
        config = {}
        config['src'] = defaults['src'].merge(gallery_opts['src'] || {})
        config['dst'] = defaults['dst'].merge(gallery_opts['dst'] || {})
        config['presets'] = defaults['presets'].merge(gallery_opts['presets'] || {})
        config['quality'] = gallery_opts['quality'] || defaults['quality']
        config['dynamic_fill'] = gallery_opts.has_key?('dynamic_fill') ? 
          gallery_opts['dynamic_fill'] : 
          defaults['dynamic_fill']
        config['pretty_json'] = gallery_opts.has_key?('pretty_json') ? 
          gallery_opts['pretty_json'] : 
          defaults['pretty_json']
        config['opts'] ||= {}
        if (gallery_opts['opts'])
          config['opts']['min_col_width'] = defaults['opts']['min_col_width'].merge(
            gallery_opts['opts']['min_col_width'] || {}
          )
          config['opts']['gutter_width'] = gallery_opts['opts']['gutter_width'] || 
            defaults['opts']['gutter_width']
          config['opts']['chunk_size'] = gallery_opts['opts']['chunk_size'] || 
            defaults['opts']['chunk_size']
          config['opts']['first_chunk'] = gallery_opts['opts']['first_chunk'] || 
            defaults['opts']['first_chunk']
        end
        return config        
      end

      # the path to the "cached" json file, it gets copied to the same path as the
      # gallery post in #generate
      def json_path site, gallery_post, gallery
        filename = "#{gallery.project}.json"
        filepath = File.join(gallery.dst[:basepath], '..' , filename)
      end

      # Generates a JSON File next to the gallery post html File. 
      #
      # It can be fetched in the browser with: 
      # $.ajax({
      #   dataType: 'json', 
      #   url: '<project>.json', 
      #   success: function(data) {
      #       console.log(data);
      #   }
      # })
      def generate_json site, gallery_post, gallery
        filepath = json_path(site, gallery_post, gallery)
        
        # Create Dst Directory if not existent yet
        filedir = File.dirname(filepath)
        FileUtils.mkdir_p(filedir) unless File.exists?(filedir)
        
        # Write the contents of gallery json.
        filename = File.basename(filepath)
        File.open(filepath, 'w') do |f|
          if gallery.pretty_json
            f.write(JSON.pretty_generate(
              { 'gallery' => gallery }
            ))
          else
            f.write(JSON.generate(
              { 'gallery' => gallery }
            ))
          end
          f.close
        end
      end
      
      def copy_json site, gallery_post, gallery
        src_filepath = json_path(site, gallery_post, gallery)
        filename = File.basename src_filepath

        dst_filepath = File.join(site.dest, gallery_post.dir, filename)
        
        # Mkdir if destination dir doesn't exist yet
        dst_dir = File.dirname dst_filepath
        FileUtils.mkdir_p(dst_dir) unless File.exists?(dst_dir)
        
        # Copy json file
        FileUtils.cp(src_filepath, dst_filepath)
        
        # Prevent Jekyll from erasing our generated files
        site.static_files << StaticGalleryFile.new(
          site, site.source, gallery_post.dir, filename
        )
      end
      
      # Copy Images and add StaticFiles for all Images to Jekyll
      #
      # We copy by ourself, because the directory structure doesn't
      # fit into the schema with which Mr. Jekyll is used to work
      # (details in Jekyll::StaticFile)
      def copy_images site, gallery
        dst_dir = File.join(site.dest, gallery.dst[:baseurl])
        # copy only when gallery has to be created by option or 
        # because of missing preset files or because dst files
        # do not exist.
        if (gallery.generate? || !File.exists?(dst_dir))
          FileUtils.mkdir_p(dst_dir) unless File.exists?(dst_dir)
          gallery.presets.each_key do |preset_key|
            FileUtils.cp_r(
              File.join(gallery.dst[:basepath], preset_key),
              dst_dir
            )
          end
        end
        # Prevent the copied files from beeing removed again by 
        # Jekylls cleanup method
        site.keep_files << gallery.dst[:baseurl] unless site.keep_files.include?(gallery.dst[:baseurl])
        gallery.images.each do |img|
          img.presets.each_key do |preset_key|
            site.static_files << StaticGalleryFile.new(
              site, '', img.dst[preset_key][:baseurl], img.dst[:filename]
            )
          end
        end
    
        # Workaround.... for issue: https://github.com/mojombo/jekyll/issues/1297
        # Have to create a virtual static file in every subdirectory of 
        # gallery dst baseurl, else these directories are washed away by
        # Jekylls cleanup method...
        site.static_files << StaticGalleryFile.new(
          site, '', gallery.dst[:baseurl], 'keepme'
        )
      end

      def log_gallery gallery, processed_yet, status
        # Filesize stats
        @galleries_size += gallery.size
        if (!processed_yet)
          @gallery_stats << "#{gallery.title}".send(status == :nothing ? 'cyan' : 'green') +
            " - #{gallery.images.size} Images, #{gallery.size.to_human}" +
            " (Quality: #{gallery.quality}%)"
          preset_stats = gallery.presets.map do |p_key, preset|
            size = preset['size']
            "  #{p_key}:\t\t#{size.to_human} (~ #{(size/gallery.images.count).floor.to_human})"
          end
          @gallery_stats << preset_stats
        end
      end

    end


    # Sub-class Jekyll::StaticFile to allow recovery from unimportant exception
    # when writing the sitemap file.
    class StaticGalleryFile < Jekyll::StaticFile
      def write(dest)
        super(dest) rescue ArgumentError
        true
      end
    end

  end
end

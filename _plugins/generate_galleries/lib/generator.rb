module Jekyll
  module GalleryGenerator
    class GalleryGenerator < Generator
        
      priority :normal
      
      def generate site
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
      
            galleries = {}; gallery_stats = []; galleries_size = 0
      
            # logging
            puts; puts "#### #{gallery_posts.size} Gallery-Posts"
                  
            gallery_posts.each do |gp|
                              
              # Front Matter YAML Data
              data = gp.data
          
              # Build Options for Gallery constructor
              opts = {}
              opts['presets'] = site.config['gallery']['presets'].dup
              opts['title'] = data['title']
              opts['presets'].merge!(data['presets']) if data.has_key?('presets')
              opts['quality'] = site.config['gallery']['quality']
              opts['quality'] = data['quality'] if data.has_key?('quality')
              opts['regenerate_images'] = data['regenerate_images'] if data.has_key?('regenerate_images')
              opts['generate_gallery'] = data['generate_gallery'] if data.has_key?('generate_gallery')
              opts['dynamic_fill'] = data['dynamic_fill'] if data.has_key?('dynamic_fill')
              # Gallery Options
              if (data.has_key?('gallery') || site.config['gallery'].has_key?('opts'))
                # fetch & merge options from site config & post
                gallery_opts = site.config['gallery']['opts'] || {}
                gallery_opts = gallery_opts.merge(data['gallery']) if data.has_key?('gallery')
                # fill gallery opts
                opts['gallery'] = {}
                opts['gallery']['min_col_width'] = gallery_opts['minColWidth'] if gallery_opts.has_key?('minColWidth')
                opts['gallery']['gutter_width'] = gallery_opts['gutterWidth'] if gallery_opts.has_key?('gutterWidth')
                opts['gallery']['chunk_size'] = gallery_opts['chunkSize'] if gallery_opts.has_key?('chunkSize')
                opts['gallery']['first_chunk'] = gallery_opts['firstChunk'] if gallery_opts.has_key?('firstChunk')
              end
          
              # Create Gallery instance
              begin
                gallery = Jekyll::GalleryGenerator::Gallery.new(site, data['project'], opts)
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
                gallery_processed_yet = galleries.keys.include?(gallery.project)
            
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
            
                # Filesize stats
                if (!gallery_processed_yet)
                  preset_stats = []
                  gallery.presets.each do |p_key, preset|
                    dirname = File.join(gallery.dst[:basepath], p_key)
                    images = Dir.glob(File.join(dirname, '*'))
                    summed_size = 0
                    images.each do |img|
                      summed_size += File.size(img)
                    end
                    preset_stats << "  #{p_key}:\t\t#{summed_size.to_human} (~ #{(summed_size/images.size).floor.to_human})"
                    gallery.size += summed_size
                  end
                  gallery_stats << "#{gallery.title}".send(status == :nothing ? 'cyan' : 'green') +
                    " - #{gallery.images.size} Images, #{gallery.size.to_human}" +
                    " (Quality: #{gallery.quality}%)"
                  gallery_stats << preset_stats
                end
            
                # Copy generated images
                unless images_remote || gallery_processed_yet
                  # We copy by ourself, because the directory structure doesn't
                  # fit into the schema with which Mr. Jekyll is used to work
                  # (details in Jekyll::StaticFile)
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
              
                end # end copy images
            
                # Save gallery id for not generating a gallery twice (with 
                # the Sets plugin some posts may be generated more than once)
                galleries[gallery.project] = gallery
            
                # Stats
                galleries_size += gallery.size
              
              end # end published
          
            end # end gallery_posts
                
            # logging
            puts; puts gallery_stats
            if galleries_size < 7516192768
              puts "Total of #{galleries_size.to_human}".green
            else 
              puts "Total of #{galleries_size.to_human} CAUTION: your quota is going to be exhausted soon!".red
            end
          end # end site.config
        end # end gallery_posts.any?
      end # end generate
      
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
          if gallery_post.data.has_key?('pretty_json') && gallery_post.data['pretty_json']
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
          site, site.dest, gallery_post.dir, filename
        )
      end
      
      # the path to the "cached" json file, it gets copied to the same path as the
      # gallery post in #generate
      def json_path site, gallery_post, gallery
        filename = "#{gallery.project}.json"
        filepath = File.join(gallery.dst[:basepath], '..' , filename)
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

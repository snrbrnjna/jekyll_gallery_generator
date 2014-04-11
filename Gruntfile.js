'use strict';

module.exports = function (grunt) {
  // show elapsed time at the end
  require('time-grunt')(grunt);
  // load all grunt tasks
  require('load-grunt-tasks')(grunt);

  // configurable paths
  var cfg = {
    dist: '_site'
  };

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    cfg: cfg,
    watch: {
      dev: {
        options: {
          livereload: 35729
        },
        files: [
          '*.{html,md,markdown}',
          '_includes/*.html',
          '_layouts/*.html',
          '_posts/**/*.{markdown,md}',
          '_plugins/**/*.rb',
          'lib/**/*.rb',
          '_includes/**/*.{html}',
          'js/**/*.js',
          'css/**/*.*',
          'bower_components/**/*.{js,css}',
          '_config.yml',
          '_plugins/**/*.rb'
        ],
        tasks: ['build:dev']
      }
    },
    connect: {
      options: {
        port: 9000,
        hostname: '0.0.0.0',
        base: '<%= cfg.dist %>',
        open: true
      },
      server: {
        options: {}
      },
      livereload: {
        options: {
          livereload: 35729,
        }
      }
    },
    copy: {
      dev: {
        // on dist build the bower components are moved by usemin
        // on dev target, we have to copy them by hand
        files: [
          {
            src: [
              'bower_components/normalize.css/normalize.css',
              'bower_components/jquery/dist/jquery.*',
              'bower_components/gallery.js/lib/*'
            ],
            dest: '<%= cfg.dist %>/'
          }
        ]
      }
    },
    useminPrepare: {
      options: {
        dest: '<%= cfg.dist %>',
        root: '.' // else the sources are searched in cfg.dist folder
      },
      html: '<%= cfg.dist %>/index.html',
    },
    usemin: {
      options: {
        assetsDirs: '<%= cfg.dist %>',
      },
      html: ['<%= cfg.dist %>/**/*.html'],
      css: ['<%= cfg.dist %>/css/**/*.css']
    },
    jekyll: {
      options: {
        bundleExec: true
      },
      build: {}
    }
  });

  grunt.registerTask('serve', function (target) {
    if (target === 'dist') {
      return grunt.task.run([ 'build', 'connect:server:keepalive' ]);
    }

    grunt.task.run([
      'build:dev',
      'connect:livereload',
      'watch:dev'
    ]);
  });

  grunt.registerTask('build', function (target) {
    if (target === 'dev') {
      return grunt.task.run([
        'jekyll:build',
        'copy:dev'
      ]);
    }

    grunt.task.run([
      'jekyll:build',
      'useminPrepare',
      'concat',
      'cssmin',
      'uglify',
      'usemin'
    ]);
  });

  grunt.registerTask('default', [
    'serve'
  ]);
};

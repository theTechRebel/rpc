module.exports = {
    entry: "./app/js/app.js",
    output: {
        path: __dirname + "/build/app/js",
        filename: "app.js"
    },
    module: {
        rules: [
            {
              test: /\.(scss)$/,
              use: [
                {
                  // Adds CSS to the DOM by injecting a `<style>` tag
                  loader: 'style-loader'
                },
                {
                  // Interprets `@import` and `url()` like `import/require()` and will resolve them
                  loader: 'css-loader'
                },
                {
                  // Loader for webpack to process CSS with PostCSS
                  loader: 'postcss-loader',
                  options: {
                    plugins: function () {
                      return [
                        require('autoprefixer')
                      ];
                    }
                  }
                },
                {
                  // Loads a SASS/SCSS file and compiles it to CSS
                  loader: 'sass-loader'
                }
              ]
            }
          ]
    }
};
const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  mode: 'development',
  entry: './app/javascript/packs/application.js',
  output: {
    path: path.resolve(__dirname, 'app/assets/javascripts'),
    // Use a distinct name to avoid colliding with Rails' default Propshaft asset
    // logical path "application.js" (which can come from app/javascript/application.js).
    filename: 'application-webpack.js',
    clean: false
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env', '@babel/preset-react']
          }
        }
      },
      {
        test: /\.css$/,
        use: [
          MiniCssExtractPlugin.loader,
          'css-loader',
          'postcss-loader'
        ]
      }
    ]
  },
  resolve: {
    extensions: ['.js', '.jsx', '.css']
  },
  optimization: {
    splitChunks: false
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: '../stylesheets/application-bundled.css',
    })
  ]
};



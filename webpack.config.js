const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

// Use NODE_ENV to determine mode, default to development for local dev
const isProduction = process.env.NODE_ENV === 'production';

module.exports = {
  mode: isProduction ? 'production' : 'development',
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
          {
            loader: 'css-loader',
            options: {
              importLoaders: 2, // Process imports and then run postcss-loader
            }
          },
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



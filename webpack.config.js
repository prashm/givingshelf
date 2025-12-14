const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  mode: 'development',
  entry: './app/javascript/packs/application.js',
  output: {
    path: path.resolve(__dirname, 'app/assets/javascripts'),
    filename: 'application.js',
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



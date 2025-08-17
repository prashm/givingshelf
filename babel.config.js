// The source code including full typescript support is available at: 
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/babel.config.js

module.exports = function (api) {
  const isProductionEnv = api.env('production')

  return {
    presets: [
      ['@babel/preset-env', { targets: { node: 'current' } }],
      [
        '@babel/preset-react',
        {
          development: !isProductionEnv,
          useBuiltIns: true
        }
      ]
    ],
    plugins: [
      process.env.WEBPACK_SERVE && 'react-refresh/babel',
      isProductionEnv && ['babel-plugin-transform-react-remove-prop-types',
        {
          removeImport: true
        }
      ]
    ].filter(Boolean)
  }
}

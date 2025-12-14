module.exports = {
  plugins: [
    require('@tailwindcss/postcss'),
    require('postcss-preset-env')({
      features: {
        'custom-properties': false,
      },
    }),
    {
      postcssPlugin: 'fix-sass-rgb',
      AtRule(rule) {
        if (rule.name === 'supports' && rule.params.includes('rgb(from red r g b)')) {
          rule.params = rule.params.replace('rgb(from red r g b)', 'sass-safe-rgb(from red r g b)');
        }
      }
    }
  ],
}


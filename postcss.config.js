module.exports = {
  plugins: [
    require('@tailwindcss/postcss'),
    require('postcss-media-minmax'),
    require('autoprefixer'),
    {
      postcssPlugin: 'fix-sass-rgb',
      AtRule(rule) {
        if (rule.name === 'supports' && rule.params.includes('rgb(from red r g b)') && !rule.params.includes('sass-safe-rgb')) {
          rule.params = rule.params.replace('rgb(from red r g b)', 'sass-safe-rgb(from red r g b)');
        }
      }
    }
  ],
}

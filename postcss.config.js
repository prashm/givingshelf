module.exports = {
  plugins: [
    require('@tailwindcss/postcss'),
    require('postcss-media-minmax'),
    require('postcss-color-functional-notation'),
    // Add postcss-nesting to flatten nested CSS for browser compatibility
    // This ensures space-y-3 and other nested classes work in all browsers
    require('postcss-nesting')({
      // Use the standard nesting syntax
      noIsPseudoSelector: true
    }),
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

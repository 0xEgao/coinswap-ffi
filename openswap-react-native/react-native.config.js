module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath: 'import org.openswap.reactnative.OpenswapReactNativePackage;',
        packageInstance: 'new OpenswapReactNativePackage()',
      },
      ios: {},
    },
  },
}

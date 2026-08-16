const installer = {
  installRustCrate() {
    return true
  },
  cleanupRustCrate() {
    return true
  },
}

export const TurboModuleRegistry = {
  getEnforcing: (moduleName: string) => {
    if (moduleName !== 'OpenswapReactNative') {
      throw new Error(`TurboModule not found: ${moduleName}`)
    }
    return installer
  },
  get: (moduleName: string) => (moduleName === 'OpenswapReactNative' ? installer : null),
}

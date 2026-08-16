const { createRunOncePlugin, withPlugins } = require('@expo/config-plugins')

const { withBinaryArtifacts } = require('./withBinaryArtifacts')
const { withOpenswapAndroid } = require('./withAndroid')
const { sdkPackage } = require('./utils')

function withOpenswap(config, options) {
  const { skipBinaryDownload = false } = options || {}

  return withPlugins(config, [
    ...(skipBinaryDownload ? [] : [withBinaryArtifacts]),
    withOpenswapAndroid,
  ])
}

module.exports = createRunOncePlugin(withOpenswap, sdkPackage.name, sdkPackage.version)

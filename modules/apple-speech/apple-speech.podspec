require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'apple-speech'
  s.version = package['version']
  s.summary = package['description']
  s.description = 'Expo local module exposing Apple Speech recognition on iOS.'
  s.homepage = 'https://expo.dev'
  s.license = 'MIT'
  s.author = 'Codex'
  s.platforms = {
    :ios => '15.1'
  }
  s.swift_version = '6.0'
  s.source = { :path => '.' }
  s.static_framework = true
  s.frameworks = 'Speech', 'AVFoundation'
  s.source_files = 'ios/**/*.{swift,h,m,mm}'
  s.dependency 'ExpoModulesCore'

  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  end
end

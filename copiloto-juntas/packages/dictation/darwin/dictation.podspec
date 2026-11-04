Pod::Spec.new do |s|
  s.name             = 'dictation'
  s.version          = '0.0.1'
  s.summary          = 'Dictado continuo nativo para Copiloto Juntas.'
  s.homepage         = 'https://github.com/liusber/meetings_liusber'
  s.license          = { :type => 'Private' }
  s.author           = 'Liusber'
  s.source           = { :path => '.' }
  s.source_files     = 'dictation/Sources/dictation/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '11.0'
  s.swift_version    = '5.0'
end

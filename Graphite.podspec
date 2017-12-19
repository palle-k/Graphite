Pod::Spec.new do |s|
  s.name = 'Graphite'
  s.version = '0.0.2'
  s.license = 'MIT'
  s.summary = 'Simple force directed graph drawing for iOS'
  s.homepage = 'https://github.com/palle-k/Graphite'
  s.authors = 'Palle Klewitz'
  s.source = { :git => 'https://github.com/palle-k/Graphite.git', :tag => s.version }

  s.ios.deployment_target = '11.0'

  s.source_files = 'Sources/*.swift'
end

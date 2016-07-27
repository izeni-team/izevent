Pod::Spec.new do |spec|
  spec.name = 'IZEvent'
  spec.version = '0.4.0'
  spec.license = { :type => 'MIT' }
  spec.homepage = 'https://dev.izeni.net/bhenderson/izevent'
  spec.authors = { 'Bryan Henderson' => 'bhenderson@izeni.com' }
  spec.summary = 'A pure-swift alternative to NSNotificationCenter. No frills. Maximum safety.'
  spec.source = { :git => 'https://dev.izeni.net/bhenderosn/izevent.git', :tag => 'v#{spec.version}' }
  spec.source_files = 'IZEvent.swift'
end

Pod::Spec.new do |s|
	s.name = 'DockProgress'
	s.version = '3.2.0'
	s.summary = 'Show progress in your app\'s Dock icon'
	s.license = 'MIT'
	s.homepage = 'https://github.com/sindresorhus/DockProgress'
	s.social_media_url = 'https://twitter.com/sindresorhus'
	s.authors = { 'Sindre Sorhus' => 'sindresorhus@gmail.com' }
	s.source = { :git => 'https://github.com/sindresorhus/DockProgress.git', :tag => "v#{s.version}" }
	s.source_files = 'Sources/**/*.swift'
	s.swift_version = '5.3'
	s.platform = :macos, '10.12'
end

Pod::Spec.new do |spec|
    spec.name                           = 'NPFoundation'
    spec.version                        = '0.1.0'
    spec.license                        = { :type => 'MIT', :file => 'LICENSE' }
    spec.homepage                       = 'https://github.com/noctisplanet/npfoundation'
    spec.authors                        = { 'Jonathan Lee' => 'Jonathan.Kaishan@gmail.com' }
    spec.summary                        = 'Extensions SDK for iOS and macOS.'
    spec.source                         = { :git => 'https://github.com/noctisplanet/npfoundation.git', :tag => spec.version.to_s }

    spec.ios.deployment_target          = '12.2'
    spec.osx.deployment_target          = '11.0'
    spec.watchos.deployment_target      = '7.0'
    spec.tvos.deployment_target         = '12.2'
    spec.visionos.deployment_target     = '1.0'

    spec.static_framework = true
    spec.frameworks                     = 'Foundation'
    spec.libraries                      = 'c++'
    spec.pod_target_xcconfig            = { 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20' }

    spec.source_files                   = 'Sources/NPFoundation/**/*.{h,c,m,cpp,mm}'
    spec.public_header_files            = 'Sources/NPFoundation/include/**/*.{h}'
    spec.module_map                     = 'Sources/NPFoundation/NPFoundation.modulemap'
end

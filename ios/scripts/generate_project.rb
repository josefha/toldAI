require 'xcodeproj'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'Told.xcodeproj'))
app = project.new_target(:application, 'Told', :ios, '18.0')
app.product_name = 'Told'
group = project.main_group.new_group('Told', 'Told')
Dir.glob(File.join(root, 'Told', '**', '*.swift')).sort.each do |file|
  ref = group.new_file(file.delete_prefix(File.join(root, 'Told') + '/'))
  app.source_build_phase.add_file_reference(ref)
end
group.new_file('Info.plist')
resources = group.new_group('Resources', 'Resources')
app.resources_build_phase.add_file_reference(resources.new_file('Assets.xcassets'))
Dir.glob(File.join(root, 'Told', 'Resources', '*.aiff')).sort.each do |file|
  app.resources_build_phase.add_file_reference(resources.new_file(File.basename(file)))
end
app.build_configurations.each do |config|
  config.build_settings.delete('ASSETCATALOG_COMPILER_APPICON_NAME')
  config.build_settings.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.toldai.preview',
    'SWIFT_VERSION' => '5.0', 'GENERATE_INFOPLIST_FILE' => 'YES',
    'INFOPLIST_KEY_CFBundleDisplayName' => 'told.',
    'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
    'INFOPLIST_FILE' => 'Told/Info.plist',
    'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone' => 'UIInterfaceOrientationPortrait',
    'TARGETED_DEVICE_FAMILY' => '1', 'CODE_SIGN_STYLE' => 'Automatic',
    'CURRENT_PROJECT_VERSION' => '1', 'MARKETING_VERSION' => '0.1.0',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES'
  })
end
tests = project.new_target(:unit_test_bundle, 'ToldTests', :ios, '18.0')
ui = project.new_target(:ui_test_bundle, 'ToldUITests', :ios, '18.0')
[tests, ui].each do |target|
  target.add_dependency(app)
  testgroup = project.main_group.new_group(target.name, target.name)
  Dir.glob(File.join(root, target.name, '*.swift')).sort.each do |file|
    target.source_build_phase.add_file_reference(testgroup.new_file(File.basename(file)))
  end
  target.build_configurations.each do |config|
    config.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER' => "com.toldai.#{target.name}", 'SWIFT_VERSION' => '5.0', 'GENERATE_INFOPLIST_FILE' => 'YES', 'TARGETED_DEVICE_FAMILY' => '1', 'CODE_SIGN_STYLE' => 'Automatic'})
    if target == tests
      config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Told.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Told'
      config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    else
      config.build_settings['TEST_TARGET_NAME'] = 'Told'
    end
  end
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(ui)
scheme.save_as(project.path, 'Told', true)
puts project.path
